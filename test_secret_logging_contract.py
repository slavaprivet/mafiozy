"""No-network contracts for the Telegram/HTTPX secret-log seal."""

import asyncio
import contextlib
import io
import logging
import os
import unittest
from pathlib import Path
from unittest import mock

import httpx

ROOT = Path(__file__).resolve().parent
os.environ.setdefault("BOT_TOKEN", "123456:secret-log-import-token")

_real_open = open


def _import_without_secret_file(path, mode="r", *args, **kwargs):
    if Path(path).resolve() == (ROOT / ".bot-token").resolve() and "w" in mode:
        return io.StringIO()
    return _real_open(path, mode, *args, **kwargs)


with mock.patch("builtins.open", side_effect=_import_without_secret_file):
    import mafiozi_bot as bot
from telegram import Bot
from telegram.error import InvalidToken, NetworkError, TelegramError
from telegram.ext._utils.networkloop import network_retry_loop
from telegram.request import BaseRequest, HTTPXRequest


WORLD = (ROOT / "world.html").read_text(encoding="utf-8")
TOKEN = "123456:PTB_SECRET_LOG_SENTINEL_ABCDEFGHIJKLMNOPQRSTUVWXYZ"
STEAM_KEY = "STEAM_SECRET_LOG_SENTINEL_ABCDEFGHIJKLMNOPQRSTUVWXYZ"


@contextlib.contextmanager
def captured_root_logs():
    root = logging.getLogger()
    old_handlers = list(root.handlers)
    old_level = root.level
    stream = io.StringIO()
    handler = logging.StreamHandler(stream)
    handler.setFormatter(logging.Formatter("%(name)s|%(levelname)s|%(message)s"))
    root.handlers[:] = [handler]
    root.setLevel(logging.DEBUG)
    bot._install_secret_log_redaction()
    try:
        yield stream, handler
    finally:
        root.handlers[:] = old_handlers
        root.setLevel(old_level)


async def mock_bot(responder, token=TOKEN):
    request = HTTPXRequest()
    await request.initialize()
    await request._client.aclose()
    request._client = httpx.AsyncClient(transport=httpx.MockTransport(responder))
    return Bot(token, request=request), request


class SecretLoggingContractTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.old_token = bot.BOT_TOKEN
        self.old_steam_key = os.environ.get("STEAM_WEB_API_KEY")
        self.old_httpx_level = logging.getLogger("httpx").level
        self.old_httpcore_level = logging.getLogger("httpcore").level
        bot.BOT_TOKEN = TOKEN
        os.environ["STEAM_WEB_API_KEY"] = STEAM_KEY

    def tearDown(self):
        bot.BOT_TOKEN = self.old_token
        if self.old_steam_key is None:
            os.environ.pop("STEAM_WEB_API_KEY", None)
        else:
            os.environ["STEAM_WEB_API_KEY"] = self.old_steam_key
        logging.getLogger("httpx").setLevel(self.old_httpx_level)
        logging.getLogger("httpcore").setLevel(self.old_httpcore_level)

    def test_scope_marker_and_transport_levels(self):
        self.assertIn(
            '<meta name="mafiozy-server-secret-log-contract" content="httpx-ptb-v1">',
            WORLD,
        )
        logging.getLogger("httpx").setLevel(logging.WARNING)
        logging.getLogger("httpcore").setLevel(logging.WARNING)
        self.assertGreaterEqual(logging.getLogger("httpx").getEffectiveLevel(), logging.WARNING)
        self.assertGreaterEqual(logging.getLogger("httpcore").getEffectiveLevel(), logging.WARNING)

    def test_final_output_redacts_exact_and_bounded_known_forms(self):
        with captured_root_logs() as (stream, _):
            try:
                raise InvalidToken(f"The token `{TOKEN}` and {STEAM_KEY} were rejected")
            except InvalidToken:
                logging.getLogger("telegram.ext").exception(
                    "Authorization: Bearer bearer_secret_1234567890 "
                    "X-Telegram-Init-Data: query_id=secret&hash=abcdef"
                )
            logging.getLogger("httpx").warning(
                "POST https://api.telegram.org/bot%s/getMe?ticket=ticket-secret-1"
                "&world_token=world-secret-2&ws_ticket=ws-secret-3&key=steam-key-4",
                TOKEN,
            )
        output = stream.getvalue()
        for secret in (
            TOKEN, STEAM_KEY, "bearer_secret_1234567890", "query_id=secret",
            "ticket-secret-1", "world-secret-2", "ws-secret-3", "steam-key-4",
        ):
            self.assertNotIn(secret, output)
        self.assertIn("[REDACTED]", output)

    def test_install_is_idempotent_and_preserves_useful_info(self):
        with captured_root_logs() as (stream, handler):
            first = handler.formatter
            bot._install_secret_log_redaction()
            self.assertIs(first, handler.formatter)
            bot.logger.info("application lifecycle ready")
            logging.getLogger("telegram.ext.Application").info("Application started")
        output = stream.getvalue()
        self.assertIn("application lifecycle ready", output)
        self.assertIn("Application started", output)

    def test_forced_transport_debug_still_redacts_auth_urls(self):
        with captured_root_logs() as (stream, _):
            logging.getLogger("httpcore.connection").setLevel(logging.DEBUG)
            logging.getLogger("httpcore.connection").debug(
                "connect https://api.telegram.org/bot%s/getUpdates?key=%s",
                TOKEN,
                STEAM_KEY,
            )
        output = stream.getvalue()
        self.assertIn("httpcore.connection", output)
        self.assertNotIn(TOKEN, output)
        self.assertNotIn(STEAM_KEY, output)

    def test_invalid_json_reflection_is_redacted(self):
        with captured_root_logs() as (stream, _):
            with self.assertRaises(TelegramError):
                BaseRequest.parse_json_payload(
                    f'not-json Authorization: Bearer {TOKEN}'.encode()
                )
        self.assertNotIn(TOKEN, stream.getvalue())
        self.assertIn("[REDACTED]", stream.getvalue())

    async def test_successful_get_me_and_send_emit_no_token(self):
        def responder(request):
            method = request.url.path.rsplit("/", 1)[-1]
            if method == "getMe":
                result = {"id": 123456, "is_bot": True,
                          "first_name": "Sentinel", "username": "sentinel_bot"}
            else:
                result = {"message_id": 1, "date": 0,
                          "chat": {"id": 123456, "type": "private"}, "text": "ok"}
            return httpx.Response(200, json={"ok": True, "result": result}, request=request)

        with captured_root_logs() as (stream, _):
            logging.getLogger("httpx").setLevel(logging.INFO)
            client, request = await mock_bot(responder)
            try:
                await client.initialize()
                await client.send_message(chat_id=123456, text="ok")
            finally:
                await client.shutdown()
        output = stream.getvalue()
        self.assertNotIn(TOKEN, output)
        self.assertIn("HTTP Request: POST", output)

    async def test_401_httpx_and_telegram_traceback_are_redacted(self):
        def responder(request):
            return httpx.Response(
                401,
                json={"ok": False, "error_code": 401, "description": "Unauthorized"},
                request=request,
            )

        with captured_root_logs() as (stream, _):
            logging.getLogger("httpx").setLevel(logging.INFO)
            client, request = await mock_bot(responder)
            try:
                with self.assertRaises(InvalidToken):
                    await network_retry_loop(
                        action_cb=client.initialize,
                        on_err_cb=None,
                        description="Bootstrap Initialize",
                        interval=0,
                        max_retries=0,
                    )
            finally:
                await request.shutdown()
        output = stream.getvalue()
        self.assertNotIn(TOKEN, output)
        self.assertIn("telegram.ext", output)
        self.assertIn("Invalid token", output)

    async def test_connect_error_keeps_generic_non_auth_failure(self):
        def responder(request):
            raise httpx.ConnectError("sentinel transport failure", request=request)

        with captured_root_logs() as (stream, _):
            client, request = await mock_bot(responder)
            try:
                with self.assertRaises(NetworkError) as raised:
                    await client.initialize()
            finally:
                await request.shutdown()
        self.assertIn("sentinel transport failure", str(raised.exception))
        self.assertNotIn(TOKEN, str(raised.exception) + stream.getvalue())

    def test_run_polling_invalid_token_boundary_has_no_raw_traceback(self):
        class InvalidApp:
            def run_polling(self, **kwargs):
                self.kwargs = kwargs
                raise InvalidToken(f"The token `{TOKEN}` was rejected")

        stderr = io.StringIO()
        with captured_root_logs() as (stream, _), contextlib.redirect_stderr(stderr):
            with self.assertRaises(SystemExit) as raised:
                bot._run_polling_secret_safe(InvalidApp())
        output = stream.getvalue() + stderr.getvalue()
        self.assertEqual(raised.exception.code, 2)
        self.assertNotIn(TOKEN, output)
        self.assertNotIn("Traceback", output)
        self.assertIn("проверь BOT_TOKEN", output)

    def test_run_polling_preserves_options_and_non_auth_failures(self):
        class ProbeApp:
            def __init__(self, error=None):
                self.error = error
                self.kwargs = None

            def run_polling(self, **kwargs):
                self.kwargs = kwargs
                if self.error:
                    raise self.error

        healthy = ProbeApp()
        bot._run_polling_secret_safe(healthy)
        self.assertEqual(
            healthy.kwargs,
            {"drop_pending_updates": True, "bootstrap_retries": -1},
        )
        for error in (KeyboardInterrupt(), SystemExit(7), RuntimeError("non-auth")):
            with self.subTest(error=type(error).__name__):
                with self.assertRaises(type(error)):
                    bot._run_polling_secret_safe(ProbeApp(error))

    def test_installed_vs_requirements_version_caveat_is_observable(self):
        requirements = (ROOT / "requirements.txt").read_text(encoding="utf-8")
        self.assertIn("python-telegram-bot==20.7", requirements)
        import telegram
        self.assertRegex(telegram.__version__, r"^\d+\.\d+(?:\.\d+)?")


if __name__ == "__main__":
    unittest.main()
