// Display/coverage catalogue extracted from existing world sources. No positions, spawns or combat authority.
const freeze=value=>{if(value&&typeof value==='object'){Object.values(value).forEach(freeze);Object.freeze(value)}return value};
export const WORLD_SKIN_PALETTE=freeze(["#FDDBB4","#F0C27F","#D4935A","#A0622A","#7A3B10","#C8A882"]);
export const NPC_NAMED_BOSSES=freeze([
  {
    "id": "unique_leila",
    "bridgeId": "npc_unique_leila",
    "leaderId": "leila",
    "label": "Лейла Беллини",
    "name": "Лейла Беллини",
    "role": "unique_npc",
    "displayRole": "boss",
    "title": "Врач",
    "gang": "Красный полумесяц",
    "look": {
      "gender": 1,
      "skin": 1,
      "body": 1,
      "face": 3,
      "hair": 5,
      "hat": 0,
      "suit": "#f1f4f7",
      "trousers": "#7f1f35",
      "hairColor": "#2a1714",
      "accent": "#d73b58"
    },
    "appearance": {
      "sex": "female",
      "skin": "#F0C27F",
      "outfit": "#f1f4f7",
      "hairColor": "#2a1714",
      "accent": "#d73b58",
      "build": 1,
      "trousers": "#7f1f35",
      "role": "boss"
    },
    "uniqueWeapon": {
      "weaponId": "leila_mercy",
      "weaponName": "Последний аргумент",
      "weaponBase": "pistol_heavy",
      "style": 0
    },
    "source": {
      "file": "world.html",
      "symbol": "UNIQUE_NPC_BLUEPRINTS",
      "line": 9545
    }
  },
  {
    "id": "unique_rustam",
    "bridgeId": "npc_unique_rustam",
    "leaderId": "rustam",
    "label": "Билли Капоне",
    "name": "Билли Капоне",
    "role": "unique_npc",
    "displayRole": "boss",
    "title": "Механик",
    "gang": "Железные волки",
    "look": {
      "gender": 0,
      "skin": 2,
      "body": 3,
      "face": 1,
      "hair": 2,
      "hat": 2,
      "suit": "#264d58",
      "trousers": "#20272a",
      "hairColor": "#111315",
      "accent": "#e58b32"
    },
    "appearance": {
      "sex": "male",
      "skin": "#D4935A",
      "outfit": "#264d58",
      "hairColor": "#111315",
      "accent": "#e58b32",
      "build": 1.07,
      "trousers": "#20272a",
      "role": "boss"
    },
    "uniqueWeapon": {
      "weaponId": "rustam_wrench",
      "weaponName": "Сварщик",
      "weaponBase": "shotgun",
      "style": 1
    },
    "source": {
      "file": "world.html",
      "symbol": "UNIQUE_NPC_BLUEPRINTS",
      "line": 9545
    }
  },
  {
    "id": "unique_marco",
    "bridgeId": "npc_unique_marco",
    "leaderId": "marco",
    "label": "Марко Моретти",
    "name": "Марко Моретти",
    "role": "unique_npc",
    "displayRole": "boss",
    "title": "Водитель",
    "gang": "Ночные колёса",
    "look": {
      "gender": 0,
      "skin": 1,
      "body": 1,
      "face": 0,
      "hair": 4,
      "hat": 1,
      "suit": "#6f1d2b",
      "trousers": "#171419",
      "hairColor": "#382015",
      "accent": "#f0c85b"
    },
    "appearance": {
      "sex": "male",
      "skin": "#F0C27F",
      "outfit": "#6f1d2b",
      "hairColor": "#382015",
      "accent": "#f0c85b",
      "build": 1,
      "trousers": "#171419",
      "role": "boss"
    },
    "uniqueWeapon": {
      "weaponId": "marco_road",
      "weaponName": "Дорожный Томми",
      "weaponBase": "tommy_gun",
      "style": 2
    },
    "source": {
      "file": "world.html",
      "symbol": "UNIQUE_NPC_BLUEPRINTS",
      "line": 9545
    }
  },
  {
    "id": "unique_vera",
    "bridgeId": "npc_unique_vera",
    "leaderId": "vera",
    "label": "Вера Фальконе",
    "name": "Вера Фальконе",
    "role": "unique_npc",
    "displayRole": "boss",
    "title": "Адвокат",
    "gang": "Белые перчатки",
    "look": {
      "gender": 1,
      "skin": 0,
      "body": 0,
      "face": 2,
      "hair": 3,
      "hat": 0,
      "suit": "#30234f",
      "trousers": "#16131f",
      "hairColor": "#d9b36c",
      "accent": "#b58cff"
    },
    "appearance": {
      "sex": "female",
      "skin": "#FDDBB4",
      "outfit": "#30234f",
      "hairColor": "#d9b36c",
      "accent": "#b58cff",
      "build": 0.94,
      "trousers": "#16131f",
      "role": "boss"
    },
    "uniqueWeapon": {
      "weaponId": "vera_verdict",
      "weaponName": "Вердикт",
      "weaponBase": "pistol_gold",
      "style": 3
    },
    "source": {
      "file": "world.html",
      "symbol": "UNIQUE_NPC_BLUEPRINTS",
      "line": 9545
    }
  },
  {
    "id": "unique_arsen",
    "bridgeId": "npc_unique_arsen",
    "leaderId": "arsen",
    "label": "Энцо Барзини",
    "name": "Энцо Барзини",
    "role": "unique_npc",
    "displayRole": "boss",
    "title": "Оружейник",
    "gang": "Чёрная кузня",
    "look": {
      "gender": 0,
      "skin": 3,
      "body": 2,
      "face": 3,
      "hair": 0,
      "hat": 3,
      "suit": "#4a3d2b",
      "trousers": "#1e1c18",
      "hairColor": "#0d0d0d",
      "accent": "#d18b42"
    },
    "appearance": {
      "sex": "male",
      "skin": "#A0622A",
      "outfit": "#4a3d2b",
      "hairColor": "#0d0d0d",
      "accent": "#d18b42",
      "build": 1.04,
      "trousers": "#1e1c18",
      "role": "boss"
    },
    "uniqueWeapon": {
      "weaponId": "arsen_forge",
      "weaponName": "Кузнечный гром",
      "weaponBase": "rifle",
      "style": 4
    },
    "source": {
      "file": "world.html",
      "symbol": "UNIQUE_NPC_BLUEPRINTS",
      "line": 9545
    }
  },
  {
    "id": "unique_damir",
    "bridgeId": "npc_unique_damir",
    "leaderId": "damir",
    "label": "Дамиано Коста",
    "name": "Дамиано Коста",
    "role": "unique_npc",
    "displayRole": "boss",
    "title": "Вербовщик",
    "gang": "Зелёный круг",
    "look": {
      "gender": 0,
      "skin": 2,
      "body": 1,
      "face": 1,
      "hair": 5,
      "hat": 0,
      "suit": "#174b3e",
      "trousers": "#11261f",
      "hairColor": "#17120f",
      "accent": "#79d6a8"
    },
    "appearance": {
      "sex": "male",
      "skin": "#D4935A",
      "outfit": "#174b3e",
      "hairColor": "#17120f",
      "accent": "#79d6a8",
      "build": 1,
      "trousers": "#11261f",
      "role": "boss"
    },
    "uniqueWeapon": {
      "weaponId": "damir_oath",
      "weaponName": "Клятва",
      "weaponBase": "smg",
      "style": 5
    },
    "source": {
      "file": "world.html",
      "symbol": "UNIQUE_NPC_BLUEPRINTS",
      "line": 9545
    }
  },
  {
    "id": "unique_marat",
    "bridgeId": "npc_unique_marat",
    "leaderId": "marat",
    "label": "Марчелло Рицци",
    "name": "Марчелло Рицци",
    "role": "unique_npc",
    "displayRole": "boss",
    "title": "Начальник охраны",
    "gang": "Стальной щит",
    "look": {
      "gender": 0,
      "skin": 1,
      "body": 3,
      "face": 2,
      "hair": 1,
      "hat": 4,
      "suit": "#263448",
      "trousers": "#111820",
      "hairColor": "#151515",
      "accent": "#65a8dc"
    },
    "appearance": {
      "sex": "male",
      "skin": "#F0C27F",
      "outfit": "#263448",
      "hairColor": "#151515",
      "accent": "#65a8dc",
      "build": 1.07,
      "trousers": "#111820",
      "role": "boss"
    },
    "uniqueWeapon": {
      "weaponId": "marat_wall",
      "weaponName": "Стена",
      "weaponBase": "shotgun",
      "style": 6
    },
    "source": {
      "file": "world.html",
      "symbol": "UNIQUE_NPC_BLUEPRINTS",
      "line": 9545
    }
  },
  {
    "id": "unique_zara",
    "bridgeId": "npc_unique_zara",
    "leaderId": "zara",
    "label": "Джина Беллуччи",
    "name": "Джина Беллуччи",
    "role": "unique_npc",
    "displayRole": "boss",
    "title": "Управляющая",
    "gang": "Золотая книга",
    "look": {
      "gender": 1,
      "skin": 2,
      "body": 1,
      "face": 0,
      "hair": 4,
      "hat": 0,
      "suit": "#8a3d17",
      "trousers": "#2a1710",
      "hairColor": "#1b1110",
      "accent": "#f1b05e"
    },
    "appearance": {
      "sex": "female",
      "skin": "#D4935A",
      "outfit": "#8a3d17",
      "hairColor": "#1b1110",
      "accent": "#f1b05e",
      "build": 1,
      "trousers": "#2a1710",
      "role": "boss"
    },
    "uniqueWeapon": {
      "weaponId": "zara_dividend",
      "weaponName": "Дивиденд",
      "weaponBase": "pistol_gold",
      "style": 7
    },
    "source": {
      "file": "world.html",
      "symbol": "UNIQUE_NPC_BLUEPRINTS",
      "line": 9545
    }
  },
  {
    "id": "unique_niko",
    "bridgeId": "npc_unique_niko",
    "leaderId": "niko",
    "label": "Нико Скарлетти",
    "name": "Нико Скарлетти",
    "role": "unique_npc",
    "displayRole": "boss",
    "title": "Разведчик",
    "gang": "Тихие глаза",
    "look": {
      "gender": 0,
      "skin": 0,
      "body": 0,
      "face": 3,
      "hair": 3,
      "hat": 5,
      "suit": "#35533a",
      "trousers": "#17241a",
      "hairColor": "#7b4b25",
      "accent": "#9ad06f"
    },
    "appearance": {
      "sex": "male",
      "skin": "#FDDBB4",
      "outfit": "#35533a",
      "hairColor": "#7b4b25",
      "accent": "#9ad06f",
      "build": 0.94,
      "trousers": "#17241a",
      "role": "boss"
    },
    "uniqueWeapon": {
      "weaponId": "niko_whisper",
      "weaponName": "Шёпот",
      "weaponBase": "sniper",
      "style": 8
    },
    "source": {
      "file": "world.html",
      "symbol": "UNIQUE_NPC_BLUEPRINTS",
      "line": 9545
    }
  },
  {
    "id": "unique_alisa",
    "bridgeId": "npc_unique_alisa",
    "leaderId": "alisa",
    "label": "Алисия Романо",
    "name": "Алисия Романо",
    "role": "unique_npc",
    "displayRole": "boss",
    "title": "Информатор",
    "gang": "Синяя сеть",
    "look": {
      "gender": 1,
      "skin": 0,
      "body": 1,
      "face": 1,
      "hair": 2,
      "hat": 1,
      "suit": "#1d4d70",
      "trousers": "#101d2b",
      "hairColor": "#c65a31",
      "accent": "#62c7ef"
    },
    "appearance": {
      "sex": "female",
      "skin": "#FDDBB4",
      "outfit": "#1d4d70",
      "hairColor": "#c65a31",
      "accent": "#62c7ef",
      "build": 1,
      "trousers": "#101d2b",
      "role": "boss"
    },
    "uniqueWeapon": {
      "weaponId": "alisa_signal",
      "weaponName": "Сигнал",
      "weaponBase": "smg",
      "style": 9
    },
    "source": {
      "file": "world.html",
      "symbol": "UNIQUE_NPC_BLUEPRINTS",
      "line": 9545
    }
  },
  {
    "id": "unique_boris",
    "bridgeId": "npc_unique_boris",
    "leaderId": "boris",
    "label": "Бруно Манчини",
    "name": "Бруно Манчини",
    "role": "unique_npc",
    "displayRole": "boss",
    "title": "Эвакуаторщик",
    "gang": "Жёлтые крюки",
    "look": {
      "gender": 0,
      "skin": 1,
      "body": 3,
      "face": 0,
      "hair": 0,
      "hat": 2,
      "suit": "#c06b16",
      "trousers": "#2d2c2a",
      "hairColor": "#3b2b1f",
      "accent": "#ffe06d"
    },
    "appearance": {
      "sex": "male",
      "skin": "#F0C27F",
      "outfit": "#c06b16",
      "hairColor": "#3b2b1f",
      "accent": "#ffe06d",
      "build": 1.07,
      "trousers": "#2d2c2a",
      "role": "boss"
    },
    "uniqueWeapon": {
      "weaponId": "boris_tow",
      "weaponName": "Буксир",
      "weaponBase": "shotgun",
      "style": 10
    },
    "source": {
      "file": "world.html",
      "symbol": "UNIQUE_NPC_BLUEPRINTS",
      "line": 9545
    }
  },
  {
    "id": "unique_inga",
    "bridgeId": "npc_unique_inga",
    "leaderId": "inga",
    "label": "Ингрид Вентури",
    "name": "Ингрид Вентури",
    "role": "unique_npc",
    "displayRole": "boss",
    "title": "Риелтор",
    "gang": "Розовый ключ",
    "look": {
      "gender": 1,
      "skin": 3,
      "body": 0,
      "face": 3,
      "hair": 5,
      "hat": 3,
      "suit": "#b24b72",
      "trousers": "#321626",
      "hairColor": "#151116",
      "accent": "#ffd0df"
    },
    "appearance": {
      "sex": "female",
      "skin": "#A0622A",
      "outfit": "#b24b72",
      "hairColor": "#151116",
      "accent": "#ffd0df",
      "build": 0.94,
      "trousers": "#321626",
      "role": "boss"
    },
    "uniqueWeapon": {
      "weaponId": "inga_deed",
      "weaponName": "Документ",
      "weaponBase": "pistol_heavy",
      "style": 11
    },
    "source": {
      "file": "world.html",
      "symbol": "UNIQUE_NPC_BLUEPRINTS",
      "line": 9545
    }
  },
  {
    "id": "unique_timur",
    "bridgeId": "npc_unique_timur",
    "leaderId": "timur",
    "label": "Тони Лучано",
    "name": "Тони Лучано",
    "role": "unique_npc",
    "displayRole": "boss",
    "title": "Курьер",
    "gang": "Синие стрелы",
    "look": {
      "gender": 0,
      "skin": 2,
      "body": 0,
      "face": 2,
      "hair": 4,
      "hat": 4,
      "suit": "#3d6eaa",
      "trousers": "#17253a",
      "hairColor": "#1d1714",
      "accent": "#ffcf4d"
    },
    "appearance": {
      "sex": "male",
      "skin": "#D4935A",
      "outfit": "#3d6eaa",
      "hairColor": "#1d1714",
      "accent": "#ffcf4d",
      "build": 0.94,
      "trousers": "#17253a",
      "role": "boss"
    },
    "uniqueWeapon": {
      "weaponId": "timur_express",
      "weaponName": "Экспресс",
      "weaponBase": "smg",
      "style": 12
    },
    "source": {
      "file": "world.html",
      "symbol": "UNIQUE_NPC_BLUEPRINTS",
      "line": 9545
    }
  },
  {
    "id": "unique_emil",
    "bridgeId": "npc_unique_emil",
    "leaderId": "emil",
    "label": "Эмилио Гамбино",
    "name": "Эмилио Гамбино",
    "role": "unique_npc",
    "displayRole": "boss",
    "title": "Тренер",
    "gang": "Красный ринг",
    "look": {
      "gender": 0,
      "skin": 0,
      "body": 3,
      "face": 1,
      "hair": 2,
      "hat": 0,
      "suit": "#8f2525",
      "trousers": "#241416",
      "hairColor": "#101010",
      "accent": "#f5e7d0"
    },
    "appearance": {
      "sex": "male",
      "skin": "#FDDBB4",
      "outfit": "#8f2525",
      "hairColor": "#101010",
      "accent": "#f5e7d0",
      "build": 1.07,
      "trousers": "#241416",
      "role": "boss"
    },
    "uniqueWeapon": {
      "weaponId": "emil_champion",
      "weaponName": "Чемпион",
      "weaponBase": "pistol_heavy",
      "style": 13
    },
    "source": {
      "file": "world.html",
      "symbol": "UNIQUE_NPC_BLUEPRINTS",
      "line": 9545
    }
  },
  {
    "id": "unique_roman",
    "bridgeId": "npc_unique_roman",
    "leaderId": "roman",
    "label": "Роман Витале",
    "name": "Роман Витале",
    "role": "unique_npc",
    "displayRole": "boss",
    "title": "Бронник",
    "gang": "Серые пластины",
    "look": {
      "gender": 0,
      "skin": 1,
      "body": 2,
      "face": 3,
      "hair": 1,
      "hat": 5,
      "suit": "#535c66",
      "trousers": "#1a1d21",
      "hairColor": "#6a5844",
      "accent": "#bcd0dc"
    },
    "appearance": {
      "sex": "male",
      "skin": "#F0C27F",
      "outfit": "#535c66",
      "hairColor": "#6a5844",
      "accent": "#bcd0dc",
      "build": 1.04,
      "trousers": "#1a1d21",
      "role": "boss"
    },
    "uniqueWeapon": {
      "weaponId": "roman_plate",
      "weaponName": "Пробойник",
      "weaponBase": "rifle",
      "style": 14
    },
    "source": {
      "file": "world.html",
      "symbol": "UNIQUE_NPC_BLUEPRINTS",
      "line": 9545
    }
  },
  {
    "id": "unique_sofia",
    "bridgeId": "npc_unique_sofia",
    "leaderId": "sofia",
    "label": "София Кастеллано",
    "name": "София Кастеллано",
    "role": "unique_npc",
    "displayRole": "boss",
    "title": "Журналист",
    "gang": "Жёлтая пресса",
    "look": {
      "gender": 1,
      "skin": 1,
      "body": 0,
      "face": 0,
      "hair": 3,
      "hat": 2,
      "suit": "#d7c33e",
      "trousers": "#29324a",
      "hairColor": "#3b2418",
      "accent": "#fff4a1"
    },
    "appearance": {
      "sex": "female",
      "skin": "#F0C27F",
      "outfit": "#d7c33e",
      "hairColor": "#3b2418",
      "accent": "#fff4a1",
      "build": 0.94,
      "trousers": "#29324a",
      "role": "boss"
    },
    "uniqueWeapon": {
      "weaponId": "sofia_headline",
      "weaponName": "Заголовок",
      "weaponBase": "pistol",
      "style": 15
    },
    "source": {
      "file": "world.html",
      "symbol": "UNIQUE_NPC_BLUEPRINTS",
      "line": 9545
    }
  },
  {
    "id": "unique_viktor",
    "bridgeId": "npc_unique_viktor",
    "leaderId": "viktor",
    "label": "Виктор Ломбарди",
    "name": "Виктор Ломбарди",
    "role": "unique_npc",
    "displayRole": "boss",
    "title": "Налётчик",
    "gang": "Бесшумные",
    "look": {
      "gender": 0,
      "skin": 3,
      "body": 1,
      "face": 2,
      "hair": 5,
      "hat": 1,
      "suit": "#211f27",
      "trousers": "#0e0d11",
      "hairColor": "#080808",
      "accent": "#9d76c9"
    },
    "appearance": {
      "sex": "male",
      "skin": "#A0622A",
      "outfit": "#211f27",
      "hairColor": "#080808",
      "accent": "#9d76c9",
      "build": 1,
      "trousers": "#0e0d11",
      "role": "boss"
    },
    "uniqueWeapon": {
      "weaponId": "viktor_night",
      "weaponName": "Тень",
      "weaponBase": "sniper",
      "style": 16
    },
    "source": {
      "file": "world.html",
      "symbol": "UNIQUE_NPC_BLUEPRINTS",
      "line": 9545
    }
  },
  {
    "id": "unique_yana",
    "bridgeId": "npc_unique_yana",
    "leaderId": "yana",
    "label": "Джанна Марино",
    "name": "Джанна Марино",
    "role": "unique_npc",
    "displayRole": "boss",
    "title": "Диспетчер",
    "gang": "Бирюзовая линия",
    "look": {
      "gender": 1,
      "skin": 2,
      "body": 1,
      "face": 2,
      "hair": 1,
      "hat": 4,
      "suit": "#17666a",
      "trousers": "#102c31",
      "hairColor": "#16100e",
      "accent": "#6de0d7"
    },
    "appearance": {
      "sex": "female",
      "skin": "#D4935A",
      "outfit": "#17666a",
      "hairColor": "#16100e",
      "accent": "#6de0d7",
      "build": 1,
      "trousers": "#102c31",
      "role": "boss"
    },
    "uniqueWeapon": {
      "weaponId": "yana_frequency",
      "weaponName": "Частота",
      "weaponBase": "smg",
      "style": 17
    },
    "source": {
      "file": "world.html",
      "symbol": "UNIQUE_NPC_BLUEPRINTS",
      "line": 9545
    }
  },
  {
    "id": "unique_musa",
    "bridgeId": "npc_unique_musa",
    "leaderId": "musa",
    "label": "Муса Карбоне",
    "name": "Муса Карбоне",
    "role": "unique_npc",
    "displayRole": "boss",
    "title": "Снабженец",
    "gang": "Золотой караван",
    "look": {
      "gender": 0,
      "skin": 3,
      "body": 2,
      "face": 0,
      "hair": 3,
      "hat": 3,
      "suit": "#6b5125",
      "trousers": "#241d12",
      "hairColor": "#19120c",
      "accent": "#e6c56a"
    },
    "appearance": {
      "sex": "male",
      "skin": "#A0622A",
      "outfit": "#6b5125",
      "hairColor": "#19120c",
      "accent": "#e6c56a",
      "build": 1.04,
      "trousers": "#241d12",
      "role": "boss"
    },
    "uniqueWeapon": {
      "weaponId": "musa_caravan",
      "weaponName": "Караван",
      "weaponBase": "rifle",
      "style": 18
    },
    "source": {
      "file": "world.html",
      "symbol": "UNIQUE_NPC_BLUEPRINTS",
      "line": 9545
    }
  }
]);
export const NPC_SAID=freeze({
  "id": "said_story_npc",
  "bridgeId": "npc_said_story_npc",
  "label": "Саид",
  "name": "Саид",
  "role": "said",
  "title": "Правая рука",
  "look": {
    "gender": 0,
    "skin": 2,
    "body": 1,
    "face": 2,
    "hair": 1,
    "hat": 0,
    "suit": "#f4f2e9",
    "trousers": "#17191c",
    "hairColor": "#17191c",
    "accent": "#d7ae4c"
  },
  "appearance": {
    "sex": "male",
    "skin": "#D4935A",
    "outfit": "#f4f2e9",
    "hairColor": "#17191c",
    "accent": "#d7ae4c",
    "build": 1,
    "trousers": "#17191c"
  },
  "source": {
    "file": "world.html",
    "symbol": "SAID_NPC",
    "line": 9534
  }
});
export const NPC_ARCHETYPE_CATALOGUE=freeze([
  {
    "id": "catalogue:archetype:worker",
    "key": "worker",
    "label": "Рабочий",
    "role": "worker",
    "catalogueOnly": true,
    "identityKind": "archetype",
    "look": {
      "body": 1
    },
    "source": {
      "file": "world.html",
      "symbol": "NPC_ARCHETYPES",
      "line": 10557
    }
  },
  {
    "id": "catalogue:archetype:pensioner",
    "key": "pensioner",
    "label": "Пенсионер",
    "role": "pensioner",
    "catalogueOnly": true,
    "identityKind": "archetype",
    "look": {
      "hat": 2
    },
    "source": {
      "file": "world.html",
      "symbol": "NPC_ARCHETYPES",
      "line": 10557
    }
  },
  {
    "id": "catalogue:archetype:student",
    "key": "student",
    "label": "Студент",
    "role": "student",
    "catalogueOnly": true,
    "identityKind": "archetype",
    "look": {
      "hat": 0
    },
    "source": {
      "file": "world.html",
      "symbol": "NPC_ARCHETYPES",
      "line": 10557
    }
  },
  {
    "id": "catalogue:archetype:housewife",
    "key": "housewife",
    "label": "Домохозяйка",
    "role": "housewife",
    "catalogueOnly": true,
    "identityKind": "archetype",
    "look": {},
    "source": {
      "file": "world.html",
      "symbol": "NPC_ARCHETYPES",
      "line": 10557
    }
  },
  {
    "id": "catalogue:archetype:businessman",
    "key": "businessman",
    "label": "Бизнесмен",
    "role": "businessman",
    "catalogueOnly": true,
    "identityKind": "archetype",
    "look": {
      "body": 2,
      "hat": 5
    },
    "source": {
      "file": "world.html",
      "symbol": "NPC_ARCHETYPES",
      "line": 10557
    }
  },
  {
    "id": "catalogue:archetype:drunk",
    "key": "drunk",
    "label": "Пьяный",
    "role": "drunk",
    "catalogueOnly": true,
    "identityKind": "archetype",
    "look": {},
    "source": {
      "file": "world.html",
      "symbol": "NPC_ARCHETYPES",
      "line": 10557
    }
  },
  {
    "id": "catalogue:archetype:bandit",
    "key": "bandit",
    "label": "Бандит",
    "role": "bandit",
    "catalogueOnly": true,
    "identityKind": "archetype",
    "look": {
      "hat": 3,
      "body": 1
    },
    "source": {
      "file": "world.html",
      "symbol": "NPC_ARCHETYPES",
      "line": 10557
    }
  },
  {
    "id": "catalogue:archetype:homeless",
    "key": "homeless",
    "label": "Бездомный",
    "role": "homeless",
    "catalogueOnly": true,
    "identityKind": "archetype",
    "look": {},
    "source": {
      "file": "world.html",
      "symbol": "NPC_ARCHETYPES",
      "line": 10557
    }
  }
]);
export const NPC_SERVICE_CATALOGUE=freeze([
  {
    "id": "catalogue:interior:hospital:0",
    "catalogueOnly": true,
    "identityKind": "role",
    "building": "hospital",
    "label": "Врач",
    "role": "medic",
    "look": {
      "gender": 1,
      "skin": 1,
      "body": 0,
      "face": 0,
      "hair": 3,
      "hat": 0,
      "suit": "#eef2f5"
    },
    "appearance": {
      "sex": "female",
      "skin": "#F0C27F",
      "outfit": "#eef2f5",
      "build": 0.94
    },
    "source": {
      "file": "world.html",
      "symbol": "_INTERIOR_NPC_CFG",
      "line": 59013
    }
  },
  {
    "id": "catalogue:interior:hospital:1",
    "catalogueOnly": true,
    "identityKind": "role",
    "building": "hospital",
    "label": "Медсестра",
    "role": "medic",
    "look": {
      "gender": 1,
      "skin": 2,
      "body": 0,
      "face": 1,
      "hair": 5,
      "hat": 0,
      "suit": "#e8f0ee"
    },
    "appearance": {
      "sex": "female",
      "skin": "#D4935A",
      "outfit": "#e8f0ee",
      "build": 0.94
    },
    "source": {
      "file": "world.html",
      "symbol": "_INTERIOR_NPC_CFG",
      "line": 59013
    }
  },
  {
    "id": "catalogue:interior:hospital:2",
    "catalogueOnly": true,
    "identityKind": "role",
    "building": "hospital",
    "label": "Санитар",
    "role": "medic",
    "look": {
      "gender": 0,
      "skin": 1,
      "body": 1,
      "face": 2,
      "hair": 0,
      "hat": 0,
      "suit": "#3a8a6a"
    },
    "appearance": {
      "sex": "male",
      "skin": "#F0C27F",
      "outfit": "#3a8a6a",
      "build": 1
    },
    "source": {
      "file": "world.html",
      "symbol": "_INTERIOR_NPC_CFG",
      "line": 59013
    }
  },
  {
    "id": "catalogue:interior:police_st:0",
    "catalogueOnly": true,
    "identityKind": "role",
    "building": "police_st",
    "label": "Сержант",
    "role": "police",
    "look": {
      "gender": 0,
      "skin": 1,
      "body": 2,
      "face": 3,
      "hair": 1,
      "hat": 5,
      "suit": "#1c2c55"
    },
    "appearance": {
      "sex": "male",
      "skin": "#F0C27F",
      "outfit": "#1c2c55",
      "build": 1.04
    },
    "source": {
      "file": "world.html",
      "symbol": "_INTERIOR_NPC_CFG",
      "line": 59013
    }
  },
  {
    "id": "catalogue:interior:police_st:1",
    "catalogueOnly": true,
    "identityKind": "role",
    "building": "police_st",
    "label": "Патрульный",
    "role": "police",
    "look": {
      "gender": 0,
      "skin": 2,
      "body": 1,
      "face": 0,
      "hair": 0,
      "hat": 5,
      "suit": "#22305c"
    },
    "appearance": {
      "sex": "male",
      "skin": "#D4935A",
      "outfit": "#22305c",
      "build": 1
    },
    "source": {
      "file": "world.html",
      "symbol": "_INTERIOR_NPC_CFG",
      "line": 59013
    }
  },
  {
    "id": "catalogue:interior:police_st:2",
    "catalogueOnly": true,
    "identityKind": "role",
    "building": "police_st",
    "label": "Следователь",
    "role": "police",
    "look": {
      "gender": 0,
      "skin": 1,
      "body": 0,
      "face": 2,
      "hair": 2,
      "hat": 0,
      "suit": "#2a2a38"
    },
    "appearance": {
      "sex": "male",
      "skin": "#F0C27F",
      "outfit": "#2a2a38",
      "build": 0.94
    },
    "source": {
      "file": "world.html",
      "symbol": "_INTERIOR_NPC_CFG",
      "line": 59013
    }
  },
  {
    "id": "catalogue:interior:mafia_hq:0",
    "catalogueOnly": true,
    "identityKind": "role",
    "building": "mafia_hq",
    "label": "Консильери",
    "role": "interior_staff",
    "look": {
      "gender": 0,
      "skin": 1,
      "body": 1,
      "face": 3,
      "hair": 2,
      "hat": 0,
      "suit": "#26151b"
    },
    "appearance": {
      "sex": "male",
      "skin": "#F0C27F",
      "outfit": "#26151b",
      "build": 1
    },
    "source": {
      "file": "world.html",
      "symbol": "_INTERIOR_NPC_CFG",
      "line": 59013
    }
  },
  {
    "id": "catalogue:interior:mafia_hq:1",
    "catalogueOnly": true,
    "identityKind": "role",
    "building": "mafia_hq",
    "label": "Капореджиме",
    "role": "interior_staff",
    "look": {
      "gender": 0,
      "skin": 2,
      "body": 2,
      "face": 1,
      "hair": 1,
      "hat": 3,
      "suit": "#3a2020"
    },
    "appearance": {
      "sex": "male",
      "skin": "#D4935A",
      "outfit": "#3a2020",
      "build": 1.04
    },
    "source": {
      "file": "world.html",
      "symbol": "_INTERIOR_NPC_CFG",
      "line": 59013
    }
  },
  {
    "id": "catalogue:interior:mafia_hq:2",
    "catalogueOnly": true,
    "identityKind": "role",
    "building": "mafia_hq",
    "label": "Охранник семьи",
    "role": "interior_staff",
    "look": {
      "gender": 0,
      "skin": 1,
      "body": 2,
      "face": 2,
      "hair": 0,
      "hat": 2,
      "suit": "#171319"
    },
    "appearance": {
      "sex": "male",
      "skin": "#F0C27F",
      "outfit": "#171319",
      "build": 1.04
    },
    "source": {
      "file": "world.html",
      "symbol": "_INTERIOR_NPC_CFG",
      "line": 59013
    }
  },
  {
    "id": "catalogue:interior:gym:0",
    "catalogueOnly": true,
    "identityKind": "role",
    "building": "gym",
    "label": "Качок",
    "role": "interior_staff",
    "look": {
      "gender": 0,
      "skin": 2,
      "body": 2,
      "face": 0,
      "hair": 0,
      "hat": 0,
      "suit": "#c03838"
    },
    "appearance": {
      "sex": "male",
      "skin": "#D4935A",
      "outfit": "#c03838",
      "build": 1.04
    },
    "source": {
      "file": "world.html",
      "symbol": "_INTERIOR_NPC_CFG",
      "line": 59013
    }
  },
  {
    "id": "catalogue:interior:gym:1",
    "catalogueOnly": true,
    "identityKind": "role",
    "building": "gym",
    "label": "Атлет",
    "role": "interior_staff",
    "look": {
      "gender": 0,
      "skin": 3,
      "body": 2,
      "face": 1,
      "hair": 1,
      "hat": 0,
      "suit": "#2858b8"
    },
    "appearance": {
      "sex": "male",
      "skin": "#A0622A",
      "outfit": "#2858b8",
      "build": 1.04
    },
    "source": {
      "file": "world.html",
      "symbol": "_INTERIOR_NPC_CFG",
      "line": 59013
    }
  },
  {
    "id": "catalogue:interior:job:0",
    "catalogueOnly": true,
    "identityKind": "role",
    "building": "job",
    "label": "Соискатель",
    "role": "interior_staff",
    "look": {
      "gender": 0,
      "skin": 1,
      "body": 0,
      "face": 2,
      "hair": 1,
      "hat": 0,
      "suit": "#3a4a5a"
    },
    "appearance": {
      "sex": "male",
      "skin": "#F0C27F",
      "outfit": "#3a4a5a",
      "build": 0.94
    },
    "source": {
      "file": "world.html",
      "symbol": "_INTERIOR_NPC_CFG",
      "line": 59013
    }
  },
  {
    "id": "catalogue:interior:job:1",
    "catalogueOnly": true,
    "identityKind": "role",
    "building": "job",
    "label": "Посетитель",
    "role": "interior_staff",
    "look": {
      "gender": 1,
      "skin": 2,
      "body": 0,
      "face": 0,
      "hair": 4,
      "hat": 0,
      "suit": "#5a3a4a"
    },
    "appearance": {
      "sex": "female",
      "skin": "#D4935A",
      "outfit": "#5a3a4a",
      "build": 0.94
    },
    "source": {
      "file": "world.html",
      "symbol": "_INTERIOR_NPC_CFG",
      "line": 59013
    }
  },
  {
    "id": "catalogue:prison_police",
    "catalogueOnly": true,
    "identityKind": "role",
    "label": "Патруль",
    "role": "prison_police",
    "look": {
      "skin": 1,
      "body": 2,
      "face": 1,
      "hair": 1,
      "hat": 2,
      "suit": "#183e68"
    },
    "appearance": {
      "skin": "#F0C27F",
      "outfit": "#183e68",
      "build": 1.04,
      "role": "police",
      "hat": "police"
    },
    "source": {
      "file": "world.html",
      "symbol": "_createPrisonStaffCop"
    }
  },
  {
    "id": "catalogue:prison_guard",
    "catalogueOnly": true,
    "identityKind": "role",
    "label": "Караул",
    "role": "prison_guard",
    "look": {
      "skin": 2,
      "body": 2,
      "face": 1,
      "hair": 3,
      "hat": 2,
      "suit": "#303940"
    },
    "appearance": {
      "skin": "#D4935A",
      "outfit": "#303940",
      "build": 1.04,
      "prisonGear": "riot_helmet_shield",
      "shield": true
    },
    "source": {
      "file": "world.html",
      "symbol": "_createPrisonStaffCop"
    }
  },
  {
    "id": "catalogue:prison_tactical",
    "catalogueOnly": true,
    "identityKind": "role",
    "label": "Тюремный спецназ",
    "role": "prison_tactical",
    "look": {
      "skin": 2,
      "body": 1,
      "face": 2,
      "hair": 2,
      "hat": 2,
      "suit": "#263f5e"
    },
    "appearance": {
      "skin": "#D4935A",
      "outfit": "#263f5e",
      "build": 1,
      "prisonGear": "tactical_helmet"
    },
    "source": {
      "file": "world.html",
      "symbol": "_spawnPrisonAssaultOfficer"
    }
  },
  {
    "id": "catalogue:prison_assault",
    "catalogueOnly": true,
    "identityKind": "role",
    "label": "Штурмовой караул",
    "role": "prison_tactical",
    "look": {
      "skin": 2,
      "body": 1,
      "face": 2,
      "hair": 2,
      "hat": 2,
      "suit": "#263f5e"
    },
    "appearance": {
      "skin": "#D4935A",
      "outfit": "#263f5e",
      "build": 1,
      "prisonGear": "riot_helmet_shield",
      "shield": true
    },
    "source": {
      "file": "world.html",
      "symbol": "_spawnPrisonAssaultOfficer"
    }
  },
  {
    "id": "catalogue:cashier",
    "catalogueOnly": true,
    "identityKind": "role",
    "label": "Кассир",
    "role": "cashier",
    "appearance": {
      "outfit": "#3a82c8"
    },
    "source": {
      "file": "world.html",
      "line": 29318
    }
  },
  {
    "id": "catalogue:owner",
    "catalogueOnly": true,
    "identityKind": "role",
    "label": "Владелец",
    "role": "owner",
    "labelTemplate": "cfg.manager",
    "source": {
      "file": "world.html",
      "line": 59112
    }
  },
  {
    "id": "catalogue:business_security",
    "catalogueOnly": true,
    "identityKind": "role",
    "label": "Начальник охраны",
    "role": "biz_ally_guard",
    "source": {
      "file": "world.html",
      "line": 59067
    }
  }
]);
export const NPC_SOURCE_CATALOGUE=freeze([
  {
    "id": "catalogue:source:0",
    "catalogueOnly": true,
    "identityKind": "source",
    "label": "Жители города и обычные пляжные жители",
    "sourceDescription": "`NPCS`, `spawnNpc` 8673/8675; `initNpcs` 10472; `maintainNpcPopulation` 10987",
    "idPattern": "`resident_${serial}`; archetype ниже",
    "authority": "Клиентский AI основной игры, не отдельный серверный NPC endpoint",
    "reference": "docs/city-rebuild/NPC_WORLD_INVENTORY.md"
  },
  {
    "id": "catalogue:source:1",
    "catalogueOnly": true,
    "identityKind": "source",
    "label": "Саид",
    "sourceDescription": "описание 9536; `_placeSaidInCity` 10470",
    "idPattern": "`said_story_npc`, role `said`, specialistId `said`",
    "authority": "Особый сюжетный NPC и существующие найм/диалоги",
    "reference": "docs/city-rebuild/NPC_WORLD_INVENTORY.md"
  },
  {
    "id": "catalogue:source:2",
    "catalogueOnly": true,
    "identityKind": "source",
    "label": "19 боссов-специалистов",
    "sourceDescription": "`UNIQUE_NPC_BLUEPRINTS`, `SPECIALIST_NPCS` 9694; `_placeUniqueNpcsInCity` 10461",
    "idPattern": "`unique_${leader_id}`, role `unique_npc`, empireBoss=true",
    "authority": "Профиль + серверное состояние империи + клиентское перемещение; исходные hp999999 из конструктора НЕ боевое здоровье",
    "reference": "docs/city-rebuild/NPC_WORLD_INVENTORY.md"
  },
  {
    "id": "catalogue:source:3",
    "catalogueOnly": true,
    "identityKind": "source",
    "label": "Эскорт и рекруты босса",
    "sourceDescription": "`EMPIRE_CREW_NPCS` 9704; `_spawnEmpireCrewArrival` 9753; `_adoptEmpireStreetRecruit` 9796; `_syncEmpireBossCrews` 9930",
    "idPattern": "`empire_crew_${leaderId}_${serial}`; принятый рекрут может сохранять свой ID",
    "authority": "Состав синхронизируется с империей; клиентские визуальные/маршрутные акторы добавлены в NPCS",
    "reference": "docs/city-rebuild/NPC_WORLD_INVENTORY.md"
  },
  {
    "id": "catalogue:source:4",
    "catalogueOnly": true,
    "identityKind": "source",
    "label": "Охрана владений империи",
    "sourceDescription": "`EMPIRE_HOLDING_GUARDS` 9705; `_spawnEmpireHoldingGuard` 9872; `_syncEmpireHoldingGuards` 9885",
    "idPattern": "`empire_guard_${leaderId}_${holding.kind}_${holding_id.replace(',','_')}_${slot}`",
    "authority": "Серверные назначения/владения, клиентские видимые посты; уже в NPCS",
    "reference": "docs/city-rebuild/NPC_WORLD_INVENTORY.md"
  },
  {
    "id": "catalogue:source:5",
    "catalogueOnly": true,
    "identityKind": "source",
    "label": "Личная банда игрока",
    "sourceDescription": "`_myGang`, сбор 67807",
    "idPattern": "`crew_${g.id}`, role `gang_fighter`, follows_player",
    "authority": "Существующий игровой отряд; не создавать повторно из server catalogue",
    "reference": "docs/city-rebuild/NPC_WORLD_INVENTORY.md"
  },
  {
    "id": "catalogue:source:6",
    "catalogueOnly": true,
    "identityKind": "source",
    "label": "Полицейское подкрепление",
    "sourceDescription": "`_policeBackupUnits`, сбор 67808",
    "idPattern": "`police_${cop.id}`, role `police`",
    "authority": "Коллекция действующей системы полиции",
    "reference": "docs/city-rebuild/NPC_WORLD_INVENTORY.md"
  },
  {
    "id": "catalogue:source:7",
    "catalogueOnly": true,
    "identityKind": "source",
    "label": "Городские патрульные, включая штат тюрьмы",
    "sourceDescription": "`cityCops`; `spawnCityCop` 11288, `initCityCops` 11347, `updateCityCops` 11388; `_createPrisonStaffCop` 11152",
    "idPattern": "`city_cop_${cop.id}`, role `police`; prisonStaff/gear/shield",
    "authority": "Клиентский AI, взаимодействующий с существующей полицией/розыском",
    "reference": "docs/city-rebuild/NPC_WORLD_INVENTORY.md"
  },
  {
    "id": "catalogue:source:8",
    "catalogueOnly": true,
    "identityKind": "source",
    "label": "Серверные полицейские реагирования",
    "sourceDescription": "`worldCops`; snapshot `d.cops` → `applyCopsTargets` 27513",
    "idPattern": "`world_cop_${cop.id}`, role `police_response`",
    "authority": "Серверный WS источник; responseTier и другие поля сохранять",
    "reference": "docs/city-rebuild/NPC_WORLD_INVENTORY.md"
  },
  {
    "id": "catalogue:source:9",
    "catalogueOnly": true,
    "identityKind": "source",
    "label": "Босс и охрана конвоя",
    "sourceDescription": "`worldEvent.boss/guards`, сбор 67809; `applyConvoyTargets(d.event)` 27501",
    "idPattern": "`world_event_${event.id}_${person.id}`, convoy_boss / convoy_guard",
    "authority": "Серверный WS `event`; x/y преобразуются в c/r",
    "reference": "docs/city-rebuild/NPC_WORLD_INVENTORY.md"
  },
  {
    "id": "catalogue:source:10",
    "catalogueOnly": true,
    "identityKind": "source",
    "label": "Бойцы опасных зон/защитники районов",
    "sourceDescription": "`aggroZones[zone].bots`; `applyAggroTargets(d.aggro)` 27614",
    "idPattern": "`aggro_${zone.id}_${bot.id}`, role из bot.kind, sourceId=bot.id",
    "authority": "Серверный WS; hireable отключается для district defender",
    "reference": "docs/city-rebuild/NPC_WORLD_INVENTORY.md"
  },
  {
    "id": "catalogue:source:11",
    "catalogueOnly": true,
    "identityKind": "source",
    "label": "Охрана гнёзд банд",
    "sourceDescription": "`gangNests[].guards`; `d.gang_nests` 27623",
    "idPattern": "`nest_${nest.id}_${guard.id}`, gang_guard либо guard.kind",
    "authority": "Серверный WS; семейство и принадлежность сохранять",
    "reference": "docs/city-rebuild/NPC_WORLD_INVENTORY.md"
  },
  {
    "id": "catalogue:source:12",
    "catalogueOnly": true,
    "identityKind": "source",
    "label": "Idle-охрана бизнеса игрока",
    "sourceDescription": "`BUSINESS_POIS`, `myBusinesses`, `_idleBusinessGuardPose`; сбор 67817",
    "idPattern": "`biz_guard_${biz.id}_${slot}`, role guard",
    "authority": "Визуальные посты по owned/guards; hp100 в сборщике — заглушка представления, не разрешение наносить урон",
    "reference": "docs/city-rebuild/NPC_WORLD_INVENTORY.md"
  },
  {
    "id": "catalogue:source:13",
    "catalogueOnly": true,
    "identityKind": "source",
    "label": "Отдельные отдыхающие",
    "sourceDescription": "`beachgoers`, `_beachgoerWorldPos`; сбор 67818",
    "idPattern": "`beach_${id}`, beach_civilian",
    "authority": "Клиентская коллекция; исключаются evacuated/carried, трупы используют death coordinates",
    "reference": "docs/city-rebuild/NPC_WORLD_INVENTORY.md"
  },
  {
    "id": "catalogue:source:14",
    "catalogueOnly": true,
    "identityKind": "source",
    "label": "Майкл и его охрана",
    "sourceDescription": "`MICHAEL_POS`, `michaelGuards`, `_michaelDecor`; сбор 67828–67836",
    "idPattern": "michael_dealer, michael_guard_${id}, michael_decor_${index}",
    "authority": "Майкл статический quest_giver; охрана либо реальные игровые экземпляры, либо декор при пустой коллекции",
    "reference": "docs/city-rebuild/NPC_WORLD_INVENTORY.md"
  },
  {
    "id": "catalogue:source:15",
    "catalogueOnly": true,
    "identityKind": "source",
    "label": "Пассажиры автобусов",
    "sourceDescription": "`_busWaiters`, `_busRiders`, сбор 67837–67838",
    "idPattern": "bus_waiter_${i}, bus_rider_${i}, bus_passenger",
    "authority": "Клиентские транспортные акторы; существующие индексные ID не подменять постоянными server IDs",
    "reference": "docs/city-rebuild/NPC_WORLD_INVENTORY.md"
  },
  {
    "id": "catalogue:source:16",
    "catalogueOnly": true,
    "identityKind": "source",
    "label": "Гоночные зрители/механики/фотограф",
    "sourceDescription": "RACE_CHEER_CREW, RACE_MECHANICS, RACE_PHOTOGRAPHER, сбор 67839–67841",
    "idPattern": "race_fan_${i}, race_mechanic_${i}, race_photographer",
    "authority": "Статические/ambient акторы",
    "reference": "docs/city-rebuild/NPC_WORLD_INVENTORY.md"
  },
  {
    "id": "catalogue:source:17",
    "catalogueOnly": true,
    "identityKind": "source",
    "label": "Медики скорой",
    "sourceDescription": "serviceVehicles с active `_medicalScene`, visible `_medicalCrew`, сбор 67842",
    "idPattern": "medic.id без добавочного внутреннего префикса, role medic",
    "authority": "Действующая сцена спасения; carrying/action/progress сохранять",
    "reference": "docs/city-rebuild/NPC_WORLD_INVENTORY.md"
  },
  {
    "id": "catalogue:source:18",
    "catalogueOnly": true,
    "identityKind": "source",
    "label": "Рабочие свалки",
    "sourceDescription": "сборщик 67863–67870 (искать workerRoutes)",
    "idPattern": "junkyard_worker_0/1/2, junkyard_worker",
    "authority": "Процедурное визуальное дополнение сборщика, НЕ серверные рабочие",
    "reference": "docs/city-rebuild/NPC_WORLD_INVENTORY.md"
  },
  {
    "id": "catalogue:source:19",
    "catalogueOnly": true,
    "identityKind": "source",
    "label": "Интерьеры зданий/банка",
    "sourceDescription": "`_buildingInt.npcs`, `_bankInt.npcs`, выбор 67804",
    "idPattern": "Исходный ID/role/type: владельцы, guards, персонал, посетители, участники рейда",
    "authority": "Отдельные локальные координаты текущего интерьера; в vault банк отдаёт пустой NPC список; не размещать их в уличной системе координат",
    "reference": "docs/city-rebuild/NPC_WORLD_INVENTORY.md"
  },
  {
    "id": "catalogue:source:20",
    "catalogueOnly": true,
    "identityKind": "source",
    "label": "Нападение на штаб/рейд в интерьере",
    "sourceDescription": "`_spawnNpcEmpireAssaultNpcs` 20399; dispatcher 59089; raid reconcile/resolve 62620",
    "idPattern": "Идентификаторы текущего encounter/roster/slot",
    "authority": "Требуются серверный token/поколение/подтверждения потерь, а не статический список guards",
    "reference": "docs/city-rebuild/NPC_WORLD_INVENTORY.md"
  },
  {
    "id": "catalogue:source:21",
    "catalogueOnly": true,
    "identityKind": "source",
    "label": "Fallback логова",
    "sourceDescription": "AGGRO_ZONES, ветка сборщика 67821–67827",
    "idPattern": "lair_fallback_${zone.id}_${i}, 12 на зону",
    "authority": "Только отсутствие живого authoritative aggro; не выдавать за server population и не создавать второй fallback в /walk",
    "reference": "docs/city-rebuild/NPC_WORLD_INVENTORY.md"
  },
  {
    "id": "catalogue:source:npc_custodies",
    "catalogueOnly": true,
    "identityKind": "source",
    "label": "Задержанные NPC",
    "sourceDescription": "WS npc_custodies → world custody projection",
    "idPattern": "Existing custody/source NPC id; preserve hidden_in_vehicle/cuffed/prisoner",
    "authority": "Серверный WS источник; не дублировать скрытых в машине задержанных",
    "reference": "docs/city-rebuild/NPC_WORLD_INVENTORY.md"
  }
]);
export const NPC_DISPLAY_CATALOGUE=freeze([NPC_SAID,...NPC_NAMED_BOSSES,...NPC_ARCHETYPE_CATALOGUE,...NPC_SERVICE_CATALOGUE]);
export function sourceLookAppearance(look={}){
 const appearance={};
 if(look.gender===0)appearance.sex='male';else if(look.gender===1)appearance.sex='female';
 if(Number.isInteger(look.skin)&&WORLD_SKIN_PALETTE[look.skin])appearance.skin=WORLD_SKIN_PALETTE[look.skin];
 if(look.suit)appearance.outfit=look.suit;
 if(look.hairColor)appearance.hairColor=look.hairColor;
 if(look.accent)appearance.accent=look.accent;
 if(look.trousers)appearance.trousers=look.trousers;
 if(Number.isInteger(look.body))appearance.build=[.94,1,1.04,1.07][look.body]??1;
 return appearance;
}
