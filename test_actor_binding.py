import hashlib
import hmac
import json
import os
import unittest
import urllib.parse

os.environ.setdefault("BOT_TOKEN", "123456:armor-authority-tests")

import mafiozi_bot as bot


TEST_TOKEN = "123456:armor-authority-tests"
NOW = 2_000_000_000


def signed_init_data(uid=42, auth_date=NOW, token=TEST_TOKEN, **extra):
    fields = {
        "auth_date": str(auth_date),
        "query_id": "AAE-test-query",
        "user": json.dumps(
            {"id": uid, "first_name": "Test", "username": "tester"},
            separators=(",", ":"),
        ),
        **{key: str(value) for key, value in extra.items()},
    }
    check_string = "\n".join(f"{key}={fields[key]}" for key in sorted(fields))
    secret = hmac.new(b"WebAppData", token.encode(), hashlib.sha256).digest()
    fields["hash"] = hmac.new(secret, check_string.encode(), hashlib.sha256).hexdigest()
    return urllib.parse.urlencode(fields)


class TelegramInitDataTests(unittest.TestCase):
    def test_valid_init_data_returns_bound_actor(self):
        actor = bot.verify_telegram_init_data(
            signed_init_data(), expected_uid="42", now=NOW, bot_token=TEST_TOKEN
        )
        self.assertEqual(actor["id"], 42)
        self.assertEqual(actor["username"], "tester")

    def test_tampered_init_data_is_rejected(self):
        raw = signed_init_data().replace("tester", "attacker")
        with self.assertRaisesRegex(ValueError, "signature"):
            bot.verify_telegram_init_data(raw, now=NOW, bot_token=TEST_TOKEN)

    def test_expired_and_future_init_data_are_rejected(self):
        with self.assertRaisesRegex(ValueError, "expired"):
            bot.verify_telegram_init_data(
                signed_init_data(auth_date=NOW - 901), now=NOW, bot_token=TEST_TOKEN
            )
        with self.assertRaisesRegex(ValueError, "future"):
            bot.verify_telegram_init_data(
                signed_init_data(auth_date=NOW + 31), now=NOW, bot_token=TEST_TOKEN
            )

    def test_foreign_uid_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "mismatch"):
            bot.verify_telegram_init_data(
                signed_init_data(uid=43), expected_uid=42, now=NOW, bot_token=TEST_TOKEN
            )

    def test_duplicate_field_and_malformed_user_are_rejected(self):
        raw = signed_init_data()
        with self.assertRaisesRegex(ValueError, "duplicate"):
            bot.verify_telegram_init_data(
                raw + "&auth_date=1", now=NOW, bot_token=TEST_TOKEN
            )
        malformed = signed_init_data(uid=0)
        with self.assertRaisesRegex(ValueError, "actor uid"):
            bot.verify_telegram_init_data(malformed, now=NOW, bot_token=TEST_TOKEN)


class WorldTokenTests(unittest.TestCase):
    def test_valid_token_is_bound_to_uid(self):
        token = bot.issue_world_token(42, now=NOW, bot_token=TEST_TOKEN)
        claims = bot.verify_world_token(
            token, expected_uid="42", now=NOW + 1, bot_token=TEST_TOKEN
        )
        self.assertEqual(claims["uid"], 42)
        self.assertEqual(claims["exp"], NOW + bot.WORLD_TOKEN_TTL)

    def test_tampered_token_is_rejected(self):
        token = bot.issue_world_token(42, now=NOW, bot_token=TEST_TOKEN)
        payload, signature = token.split(".")
        replacement = "A" if payload[-1] != "A" else "B"
        with self.assertRaisesRegex(ValueError, "signature"):
            bot.verify_world_token(
                payload[:-1] + replacement + "." + signature,
                now=NOW + 1,
                bot_token=TEST_TOKEN,
            )

    def test_expired_future_and_foreign_tokens_are_rejected(self):
        token = bot.issue_world_token(42, now=NOW, bot_token=TEST_TOKEN)
        with self.assertRaisesRegex(ValueError, "expired"):
            bot.verify_world_token(token, now=NOW + bot.WORLD_TOKEN_TTL, bot_token=TEST_TOKEN)
        with self.assertRaisesRegex(ValueError, "future"):
            bot.verify_world_token(token, now=NOW - 31, bot_token=TEST_TOKEN)
        with self.assertRaisesRegex(ValueError, "mismatch"):
            bot.verify_world_token(
                token, expected_uid=43, now=NOW + 1, bot_token=TEST_TOKEN
            )

    def test_wrong_secret_and_oversized_ttl_are_rejected(self):
        token = bot.issue_world_token(42, now=NOW, bot_token=TEST_TOKEN)
        with self.assertRaisesRegex(ValueError, "signature"):
            bot.verify_world_token(token, now=NOW + 1, bot_token="other:test")
        with self.assertRaisesRegex(ValueError, "lifetime"):
            bot.issue_world_token(
                42,
                now=NOW,
                ttl_seconds=bot.WORLD_TOKEN_TTL + 1,
                bot_token=TEST_TOKEN,
            )


if __name__ == "__main__":
    unittest.main()
