# Astra 6 — exact received prefix

Collection date: 2026-09-26. Thread: `6ab2cebc-b550-83e9-a07f-0ff790a47236`. AgentMessage: `c9b6e3cf-2055-4133-9787-ff9ad99fd3de`. Turn: `020e3fa4-d4de-43b4-b23e-1481b4c1f5cd`.
CompletedAt: 1790452013.674192 (2026-09-26T19:46:53.674Z); updatedAt: 1790452017.067622.
Received characters: 20000; server truncated: true.

**PARTIAL PACKAGE: 20000-character prefix only.** Statements below about complete files/bundles describe the author's full answer, not what read_thread delivered. Sandbox attachments not downloaded. Claimed PASS counts are not independently repeated. Godot/runtime/GPU/integration not run by collector; no production changed.

Closed file blocks extracted only: none; resource_audit.py block is incomplete. Remaining schema/test/runtime blocks are unavailable or incomplete. Original claimed hashes and computed local hashes are distinct in review manifest. No final integration acceptance.

<!-- BEGIN EXACT RECEIVED PREFIX -->
## S00 resource audit — отдельный proposal для local review

**Canonical подтверждён:** `3612fa62f8d3bcb6888c7028ed0791fe0c928085`, tree — `25597bdd36f639ab03554efeace75bfc59f08f4e`. Подготовлен самостоятельный read-only инструмент; importer/exporter, Godot-проект и source-lock root20 он не заменяет. Production, Git, server и saves не изменены; GPU не открывался. 

**Godot `4.7.2-stable` подтверждён официальными страницами:** выпуск от 18 августа 2026 года. Это подтверждение существования версии, **не проверка установленного у root20 бинарника**. :chatgpt-content-reference{index="1"}

```text
TASK_ID: s00-resource-audit-3612fa6-v1
STATUS: PROPOSAL_READY_FOR_LOCAL_REVIEW
CANONICAL: 3612fa62f8d3bcb6888c7028ed0791fe0c928085
UNIT_TESTS: 31/31 PASS
FULL_REPOSITORY_BINARY_AUDIT: NOT_RUN
GODOT_IMPORT / NATIVE_RESOURCE_REUSE / PERFORMANCE: NOT_RUN
INTEGRATION_APPROVAL: NONE
```

### Главные результаты аудита исходников

**Raw GLB недостаточно для переноса фактического Walk.** Автомобильный адаптер клонирует и изменяет геометрию, перестраивает салон и материалы; отдельные сборщики создают кузовные панели, стекло и детальные колёса. Здания получают процедурные проёмы, этажи и интерьеры; ландшафт, вода и тропы генерируются из плана. Эти пять подтверждённых направлений внесены в отдельный ledger — **неполный перечень генераторов, а начальный список для сопоставления с exporter root20**. 

Манифест vehicle pack декларирует **12 GLB, суммарно 2 648 204 байта**, то есть около 2,526 MiB файлов. Это **не объём ресурсов после импорта и не измерение памяти**. Полные бинарные файлы здесь не перепроверены. У героя отдельно объявлен GLB размером 652 732 байта; wrapper требует именованные кости и программно формирует позы — наличие skeleton нельзя принимать за наличие всех игровых анимаций в GLB. 

### Что делает инструмент

Он читает **Git blobs закреплённого commit**, а не изменяемые файлы рабочего дерева; разбирает GLB без запуска Three/Godot; учитывает определения primitives/materials/skins/textures/images/animations и ссылки между ними. Имена не используются как идентичность. Отдельно выдаются совпадения полных файлов и закодированных изображений — **только кандидаты для ревью, без автоматического объединения**.

`primitive count`, число mesh nodes, будущие Godot surfaces и draw calls намеренно не смешаны. Логические размеры accessors не объявляются GPU-памятью; они могут пересекаться по исходным buffers. Неизвестные extensions сохраняются. Это ограниченный resource auditor, **не полный glTF validator и не декодер Draco/Meshopt/изображений**. :chatgpt-content-reference{index="4"}

### Контракт повторного использования для root20

Импортированный неизменяемый Mesh/Texture/Animation можно рассматривать для совместного использования при совпадении **исходных байтов, зависимостей, настроек импорта, версии движка и платформы**. Узлы, transforms и skeleton pose остаются экземплярными. Godot кеширует ресурсы по путям; `resource_local_to_scene` позволяет получать отдельный ресурс на экземпляр сцены, но изменение этого флага позднее не исправляет уже созданные экземпляры. **Снижение числа копий ресурсов не означает автоматического снижения draw calls.** :chatgpt-content-reference{index="5"}

Для повреждений, fracture, paint и изменяемой emissive-интенсивности необходим явный mutable owner либо copy-before-write. Skin нельзя объединять только по именам костей: важны ordered binds, inverse bind matrices и привязка skeleton. Не предлагаю сокращать weights, отключать textures, менять tint/alpha, уменьшать LOD или переупаковывать арт. Настройки генерации tangents, shadow meshes, LOD и UV2 должны входить в fingerprint импорта, поскольку влияют на его работу и результат. :chatgpt-content-reference{index="6"}

**Import costs сейчас `NOT_RUN`.** Root20 должен отдельно измерить cold import, unchanged warm import, создание экземпляров и release/rebuild — с binary SHA Godot, import-settings SHA, платформой, исходным manifest SHA, сырыми samples и p50/p95. Эти недетерминированные измерения не подмешиваются в source manifest.

---

## Передаваемые файлы

Все четыре файла ниже приведены полностью. Сохранение — **UTF‑8 без BOM, LF, завершающий перевод строки**. Держать вместе в отдельном proposal-каталоге, не поверх файлов root20.

```text
resource_audit.py
manifest.schema.json
generated_ledger.json
test_resource_audit.py
```

SHA256 точных файлов:

```text
0ec077b7f0977bc9cd85ea0762e75d5e9054bc083277546890142b642b0007b3  resource_audit.py
4368eb7ae28cf2ed85208faf42656e7f9379aecf851eb098f1693652bc68d96a  manifest.schema.json
a38977298c261131de3034192537644e1309bc6876266e23701da8a1d4273a98  generated_ledger.json
a4491633157600040906e13e49dde4c232309b5cea87b87f2a6acac3c0e2656b  test_resource_audit.py
```

:chatgpt-content-reference{index="8"}[Копия тех же четырёх файлов в ZIP](sandbox:/mnt/data/s00_resource_proposal_3612fa6.zip).

### Команды local review

Нужны Python ≥3.10 и существующие локальные Git objects. Сам auditor использует только стандартную библиотеку Python. `jsonschema` нужен лишь для последнего schema-теста: без него этот тест явно получает `SKIP`; в выполненном прогоне он был установлен.

```bash
python -B -m unittest -v test_resource_audit

# Весь набор tracked GLB закреплённого commit.
# Выходной файл — вне production checkout.
python -B resource_audit.py /path/to/existing-checkout > /outside/checkout/resources.json

# Ограниченный первый прогон. --path можно повторять.
python -B resource_audit.py /path/to/existing-checkout \
  --path assets/maps/city_rebuild_v1/models/artist_vehicle_pack/city_suv.glb \
  > /outside/checkout/suv_resources.json
```

Код выхода `0` означает **source audit без обнаруженных ошибок входа**, не разрешение интеграции. Код `2` — блокирующая ошибка. По умолчанию анализируются все tracked `.glb`, включая потенциально неиспользуемые: **runtime reachability определяет root20**.

Внутри результата `tool_sha256` — SHA256 байтов Python-файла; `ledger_sha256` — SHA256 **канонического JSON ledger**, поэтому он отличается от SHA256 красиво отформатированного файла выше. Поля `git_blob` — **Git SHA‑1**, не SHA256.

---

## 1/4 — `resource_audit.py`

```python
#!/usr/bin/env python3
"""S00 read-only GLB resource inventory. Not a Godot importer or glTF validator.
Python 3.10+. No network, GPU, checkout writes, resource conversion or deduplication.
"""
import argparse
import base64
import hashlib
import json
import math
import os
import posixpath
import re
import struct
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path
from urllib.parse import unquote, urlsplit

COMMIT = '3612fa62f8d3bcb6888c7028ed0791fe0c928085'
TREE = '25597bdd36f639ab03554efeace75bfc59f08f4e'
LIMIT = 256 * 1024 * 1024
COMPONENT = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}
WIDTH = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4,
         'MAT2': 4, 'MAT3': 9, 'MAT4': 16}


def canonical(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True,
                       separators=(',', ':'), allow_nan=False) + '\n').encode('utf-8')


def digest(data):
    return hashlib.sha256(data).hexdigest()


def error_text(error):
    if isinstance(error, subprocess.CalledProcessError):
        return f'GitReadError(exit={error.returncode})'
    return type(error).__name__ + ': ' + str(error).splitlines()[0]


def require(ok, message):
    if not ok:
        raise ValueError(message)


def integer(value, label, minimum=0):
    require(type(value) is int and value >= minimum, 'invalid ' + label)
    return value


def ref(items, index, label):
    integer(index, label)
    require(index < len(items), 'out-of-range ' + label)
    return items[index]


def load_json(data):
    def pairs(rows):
        result = {}
        for key, value in rows:
            require(key not in result, 'duplicate JSON key: ' + key)
            result[key] = value
        return result
    def constant(value):
        raise ValueError('non-finite JSON number: ' + value)
    def number(value):
        result = float(value)
        require(math.isfinite(result), 'non-finite JSON float')
        return result
    return json.loads(data, object_pairs_hook=pairs, parse_constant=constant, parse_float=number)


class Snapshot:
    """Read Git objects, never the mutable worktree, index or checkout files."""
    def __init__(self, repo, commit=COMMIT):
        require(re.fullmatch(r'[0-9a-f]{40}', commit) is not None, 'full commit SHA required')
        self.repo, self.commit = str(Path(repo).resolve()), commit
        require(self.git('rev-parse', commit + '^{commit}').decode().strip() == commit,
                'commit mismatch')
        self.tree = self.git('rev-parse', commit + '^{tree}').decode().strip()
        if commit == COMMIT:
            require(self.tree == TREE, 'canonical tree mismatch')
        self.entries = {}
        for row in self.git('ls-tree', '-rz', '--full-tree', commit).split(b'\0'):
            if not row:
                continue
            header, path = row.split(b'\t', 1)
            mode, kind, oid = header.decode('ascii').split()
            self.entries[path.decode('utf-8')] = (mode, kind, oid)

    def git(self, *args):
        env = dict(os.environ, GIT_OPTIONAL_LOCKS='0', GIT_NO_LAZY_FETCH='1',
                   GIT_TERMINAL_PROMPT='0', GIT_NO_REPLACE_OBJECTS='1')
        return subprocess.run(['git', '-C', self.repo, *args], env=env, check=True,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout

    def read(self, path):
        require(path in self.entries, 'missing snapshot path: ' + path)
        mode, kind, oid = self.entries[path]
        require(kind == 'blob' and mode in ('100644', '100755'),
                'not a regular snapshot blob: ' + path)
        size = int(self.git('cat-file', '-s', oid))
        require(size <= LIMIT, 'blob exceeds audit limit: ' + path)
        data = self.git('cat-file', 'blob', oid)
        actual = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
        require(actual == oid, 'Git blob integrity failure: ' + path)
        return data


def uri_bytes(reader, path, uri):
    require(isinstance(uri, str), 'URI must be a string')
    if uri.startswith('data:'):
        head, sep, payload = uri.partition(',')
        require(sep and head.endswith(';base64'), 'only base64 data URIs supported')
        require(len(payload) <= (LIMIT * 4 // 3 + 4), 'data URI exceeds limit')
        return base64.b64decode(payload, validate=True), 'data-uri'
    decoded = unquote(uri)
    value = urlsplit(decoded)
    require(not value.scheme and not value.netloc and not value.query and not value.fragment,
            'external/qualified URI forbidden: ' + uri)
    require(decoded and not decoded.startswith('/') and '\\' not in decoded and '\0' not in decoded,
            'unsafe URI: ' + uri)
    target = posixpath.normpath(posixpath.join(posixpath.dirname(path), decoded))
    require(target != '..' and not target.startswith('../'), 'URI escapes snapshot: ' + uri)
    return reader.read(target), target


def split_glb(data):
    if data.startswith(b'version https://git-lfs.github.com/spec/'):
        raise ValueError('LFS_POINTER_NOT_ASSET_BYTES')
    require(20 <= len(data) <= LIMIT, 'invalid GLB size')
    magic, version, length = struct.unpack_from('<4sII', data)
    require(magic == b'glTF' and version == 2 and length == len(data), 'invalid GLB header')
    chunks, at = [], 12
    while at < length:
        require(at + 8 <= length, 'truncated GLB chunk header')
        size, kind = struct.unpack_from('<II', data, at)
        at += 8
        require(size % 4 == 0 and at + size <= length, 'invalid GLB chunk range')
        chunks.append((kind, data[at:at + size]))
        at += size
    require(chunks[0][0] == 0x4E4F534A, 'JSON must be the first GLB chunk')
    require(sum(k == 0x4E4F534A for k, _ in chunks) == 1, 'duplicate JSON chunk')
    bins = [b for k, b in chunks if k == 0x004E4942]
    require(len(bins) <= 1, 'duplicate BIN chunk')
    if bins:
        require(len(chunks) > 1 and chunks[1][0] == 0x004E4942, 'BIN must be second')
    doc = load_json(chunks[0][1].decode('utf-8'))
    require(isinstance(doc, dict) and doc.get('asset', {}).get('version') == '2.0',
            'glTF 2.0 asset required')
    return doc, bins[0] if bins else None, [hex(k) for k, _ in chunks
                                         if k not in (0x4E4F534A, 0x004E4942)]


def audit_glb(reader, path, data):
    doc, binary, unknown_chunks = split_glb(data)
    def array(name):
        rows = doc.get(name, [])
        require(isinstance(rows, list), 'expected array: ' + name)
        require(all(isinstance(row, dict) for row in rows), 'expected objects: ' + name)
        return rows
    buffers, views, accessors = array('buffers'), array('bufferViews'), array('accessors')
    meshes, materials, images = array('meshes'), array('materials'), array('images')
    textures, samplers, nodes = array('textures'), array('samplers'), array('nodes')
    skins, animations = array('skins'), array('animations')
    blobs, dependencies = [], {}
    for i, buffer in enumerate(buffers):
        declared = integer(buffer.get('byteLength'), 'buffer.byteLength', 1)
        if 'uri' in buffer:
            blob, location = uri_bytes(reader, path, buffer['uri'])
        else:
            require(i == 0 and binary is not None, 'missing implicit BIN buffer')
            blob, location = binary, 'glb-bin'
            require(declared <= len(blob) <= declared + 3, 'invalid BIN padding length')
        require(declared <= len(blob), 'buffer shorter than declared')
        dependencies['buffer:' + str(i)] = {'location': location, 'bytes': len(blob),
                                           'sha256': digest(blob)}
        require(sum(map(len, blobs)) + declared <= LIMIT, 'aggregate buffers exceed limit')
        blobs.append(blob[:declared])
    def view_bytes(index):
        v = ref(views, index, 'bufferView')
        source = ref(blobs, v.get('buffer'), 'bufferView.buffer')
        offset = integer(v.get('byteOffset', 0), 'bufferView.byteOffset')
        size = integer(v.get('byteLength'), 'bufferView.byteLength', 1)
        require(offset + size <= len(source), 'bufferView exceeds buffer')
        return source[offset:offset + size]
    for i in range(len(views)):
        view_bytes(i)
    accessor_rows = []
    for i, a in enumerate(accessors):
        size = COMPONENT.get(a.get('componentType'))
        width = WIDTH.get(a.get('type'))
        require(size is not None and width is not None, 'unsupported accessor layout')
        count = integer(a.get('count'), 'accessor.count', 1)
        logical = size * width * count
        element = size * width
        if a['type'].startswith('MAT'):
            columns = int(a['type'][-1])
            element = columns * ((columns * size + 3) // 4 * 4)
        if 'bufferView' in a:
            v = ref(views, a['bufferView'], 'accessor.bufferView')
            stride = integer(v.get('byteStride', element), 'accessor stride', element)
            offset = integer(a.get('byteOffset', 0), 'accessor.byteOffset')
            require(offset % size == 0 and stride % size == 0, 'unaligned accessor')
            require(offset + (count - 1) * stride + element <= len(view_bytes(a['bufferView'])),
                    'accessor exceeds bufferView')
        sparse = a.get('sparse')
        if sparse is not None:
            n = integer(sparse.get('count'), 'sparse.count', 1)
            require(n <= count, 'sparse count exceeds accessor count')
            for name, unit in [('indices', None), ('values', element)]:
                s = sparse[name]
                if name == 'indices':
                    require(s.get('componentType') in (5121, 5123, 5125), 'invalid sparse index type')
                    unit = COMPONENT[s['componentType']]
                offset = integer(s.get('byteOffset', 0), 'sparse offset')
                require(offset + n * unit <= len(view_bytes(s['bufferView'])), 'sparse data exceeds view')
        accessor_rows.append({'index': i, 'definition': a, 'logical_decoded_bytes': logical})
    def accessor(index):
        return ref(accessors, index, 'accessor reference')
    mesh_users, skin_users = defaultdict(list), defaultdict(list)
    for i, node in enumerate(nodes):
        for child in node.get('children', []):
            ref(nodes, child, 'node child')
        if 'mesh' in node:
            ref(meshes, node['mesh'], 'node.mesh')
            mesh_users[node['mesh']].append(i)
        if 'skin' in node:
            ref(skins, node['skin'], 'node.skin')
            skin_users[node['skin']].append(i)
    for scene in array('scenes'):
        for index in scene.get('nodes', []):
            ref(nodes, index, 'scene root')
    if 'scene' in doc:
        ref(array('scenes'), doc['scene'], 'default scene')
    primitive_rows, material_users = [], defaultdict(list)
    for mi, mesh in enumerate(meshes):
        require(isinstance(mesh.get('primitives'), list) and mesh['primitives'], 'mesh has no primitives')
        for pi, primitive in enumerate(mesh['primitives']):
            key = f'mesh:{mi}/primitive:{pi}'
            attrs = primitive.get('attributes', {})
            require(isinstance(attrs, dict), 'invalid primitive attributes')
            for index in attrs.values():
                accessor(index)
            if 'indices' in primitive:
                ix = accessor(primitive['indices'])
                require(ix['type'] == 'SCALAR' and ix['componentType'] in (5121, 5123, 5125),
                        'invalid index accessor')
            if 'material' in primitive:
                ref(materials, primitive['material'], 'primitive.material')
                material_users[primitive['material']].append(key)
            for target in primitive.get('targets', []):
                for index in target.values():
                    accessor(index)
            vertices = accessor(attrs['POSITION'])['count'] if 'POSITION' in attrs else None
            elements = accessor(primitive['indices'])['count'] if 'indices' in primitive else vertices
            mode = primitive.get('mode', 4)
            require(type(mode) is int and 0 <= mode <= 6, 'invalid primitive mode')
            triangles = None if elements is None else (elements // 3 if mode == 4 else
                        max(0, elements - 2) if mode in (5, 6) else 0)
            primitive_rows.append({'id': key, 'mesh': mi, 'definition': primitive,
                                   'node_users': mesh_users[mi], 'declared_vertices': vertices,
                                   'declared_triangles_including_degenerate': triangles})
    image_rows = []
    for i, image in enumerate(images):
        require(('uri' in image) != ('bufferView' in image), 'image needs exactly one source')
        if 'uri' in image:
            blob, location = uri_bytes(reader, path, image['uri'])
        else:
            blob, location = view_bytes(image['bufferView']), 'bufferView:' + str(image['bufferView'])
        image_rows.append({'index': i, 'definition': image, 'location': location,
                           'encoded_bytes': len(blob), 'encoded_sha256': digest(blob),
                           'decoded_vram_bytes': None})
    for texture in textures:
        if 'sampler' in texture:
            ref(samplers, texture['sampler'], 'texture.sampler')
        if 'source' in texture:
            ref(images, texture['source'], 'texture.source')
        for value in texture.get('extensions', {}).values():
            if isinstance(value, dict) and 'source' in value:
                ref(images, value['source'], 'texture extension source')
    def texture_refs(value, pointer=''):
        found = []
        if isinstance(value, dict):
            for key in sorted(value):
                item, at = value[key], pointer + '/' + key
                if key.endswith('Texture')
<!-- END EXACT RECEIVED PREFIX -->

