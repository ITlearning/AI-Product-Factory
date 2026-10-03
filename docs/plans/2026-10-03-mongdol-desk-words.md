# 몽돌 「사진 한 단어」 책상·식탁 위 순우리말 후보

2026-10-03 · 조사만, 코드는 고치지 않음 · 대상: `Shared/Word/words.json`(v2, 54단어) · 앞선 조사: [2026-10-03-mongdol-word-candidates.md](2026-10-03-mongdol-word-candidates.md)

> 「책이나 책상 혹은 책상위에 뭐가 있다고만 하면 다 손때, 말벗 뭐 이런걸로 퉁치던데 그게 너무 싫어서 이걸 고도화 시키려고 하는거야」 — Tabber

지금 책상·식탁 사진에 붙는 말은 배경 라벨에 걸려 있다. 손때는 `book`·`desk`·`table`·`wood_processed`, 짬은 `laptop`·`computer`·`desk`·`cup`, 겨를은 `laptop`·`computer`·`book`, 말벗은 `people` 하나로 붙는다. 이 문서는 책상 위에 **실제로 놓인 물건**과 **찍은 때**가 같이 맞아야 붙는 말을 찾았다.

## 검증 방법
- 모든 후보는 표준국어대사전 상세 화면(`contentViewOne.do`)을 스크립트로 직접 내려받아 뜻풀이·원어란·**어원란**까지 확인했다. 표준국어대사전에 없는 말만 우리말샘에서 찾았다. 출처 칸의 「표준 번호」는 표준국어대사전 word_no 링크다.
- 고유어 판정 기준은 앞선 조사와 같다. 원어란에 한자가 없고 어원란에도 한자가 없을 때만 통과. 이번에 이 기준으로 걸러진 말은 촛불(초←燭), 붓질(붓←筆), 길라잡이(←羅將), 숭늉(←熟冷), 심지(心지)다.
- 라벨은 `vision-labels.txt`에 있는 것만 썼다. 조약돌 이름(`pebble-names.txt`), 지금 목록(`words.json`), 앞선 조사의 후보와 겹치는지도 스크립트로 같이 검사했다(통과).
- 3절 예시는 `WordPicker.candidates`(규칙 후보 → 계절 완화 → 순간의 말)를 파이썬으로 그대로 옮겨 돌린 결과다. 이번 후보의 시각·달·기온·평일·AND 조건은 완화 없이 엄격하게 적용했다.
- 「제안값」이라고 적은 문턱은 근거 없는 내 제안이다. ★ = 각 절에서 가장 추천하는 말.
- 추천한 말 가운데 북한어·방언·옛말 표시가 붙은 말은 없다. 「내음」(2010)과 「잎새」(2015)는 비표준어였다가 표준어로 인정된 말이다.

## 0. 이번 후보에 새로 필요한 조건
앞선 조사 0절(라벨 AND·시(hour)·달·기온·원본 condition)에 더해, 이번에 새로 필요한 것만 적는다.

| 조건 | 왜 | 쓰는 후보 |
|---|---|---|
| **평일**(요일) | 「일을 하는 곳」「일에서 손을 뗀 겨를」은 주말·밤이면 거짓일 가능성이 크다. 요일은 찍은 날짜로 계산된다. 공휴일은 따로 달력이 있어야 한다(요확인) | 일터, 짬(개정) |
| **사람 수 2명 이상** | `people`은 혼자 찍힌 사진, 지나가는 사람에게도 붙는다. 「여러 사람」「같은 자리」를 말하려면 사람 수가 필요하다. Vision `VNDetectHumanRectanglesRequest`(iOS 13+, iPhoneOS 26.0 SDK 헤더로 존재 확인)가 사람 영역을 하나씩 돌려주므로 셀 수 있다. 식탁 사진에서 얼마나 잘 세는지는 요확인 | 잔치, 한자리 |
| **과일별 제철 달 표** | 「제철」은 과일마다 달이 다르다 | 제철 |
| 라벨 AND | 앞선 조사와 같음 | 잔치·적바림·글월·일터·짬·불그림자·한자리 |
| 시(hour)·달·기온 | 앞선 조사와 같음 | 낮술·밤술·늦아침·늦저녁·여름나기·겨울나기·일터·짬·불그림자 |

**라벨 문턱이 같이 움직인다.** `PhotoLabeler`는 단어가 쓰는 라벨만 정밀도 70%·확신도 0.15로 느슨하게 받는다. 그래서 단어에 `handwriting`·`sticky_note`·`beer`·`pizza` 같은 구체 라벨을 걸면 그 라벨이 잡힐 가능성도 같이 오른다(3절 예시의 \* 표시). 반대로 손때·겨를·짬을 빼면 `desk`·`table`·`wood_processed`가 어휘에서 빠진다(스크립트로 확인). 셋 다 배경 라벨이라 빠지는 편이 낫다. `book`은 갈피·읽을거리가, `laptop`·`computer`는 일터·짬(개정)이, `cup`은 목축임이 계속 쓰므로 느슨한 문턱이 유지된다.

## 1. 후보 (장면별)
배경 라벨(`desk`·`table`·`furniture`·`wood_processed`·`structure`·`container`·`consumer_electronics`·`machine`·`cord`·`people`·`adult`·`tableware`·`utensil`)만으로 붙는 말은 없다. `people`은 잔치·한자리에서 「그리고」로만 쓴다.

### 1-1. 마실 것
| 단어 | 사전 뜻 요약 | 앱용 한 줄 뜻 | 붙일 라벨 | 시각·날씨·기온 조건 | 주장하는 사실 → 확인 수단 | 출처 | 비고 |
|---|---|---|---|---|---|---|---|
| **★내음** | ((흔히 다른 명사 뒤에 쓰여)) 코로 맡을 수 있는 나쁘지 않거나 향기로운 기운. 주로 문학적 표현에 쓰인다 | 코끝에 닿는 향긋한 기운 | `coffee`·`coffee_bean`·`tea_drink`·`teapot`·`bread`·`baked_goods`·`croissant`·`pastry`·`muffin`·`scone` | 없음 | 향이 난다 → 그 자체로 향이 나는 것(커피·차·빵) 라벨만 | [표준 64189](https://stdict.korean.go.kr/search/searchView.do?word_no=64189&searchKeywordTo=3) | 2010년 표준어 인정. 사전이 「흔히 다른 명사 뒤에」라고 적어 홀로 보이면 조금 낯설 수 있다. 꽃은 향이 없는 종이 많아 걸지 않았다. 「꽃내음」은 사전에 한 단어로 없다(4절) |
| **★낮술** | 낮에 마시는 술 | 낮에 마시는 술 | `beer`·`wine`·`red_wine`·`white_wine`·`sparkling_wine`·`cocktail`·`liquor`·`sangria`·`margarita`·`martini`·`mojito`·`tequila` | 11:00–16:59(낮·오후 칸) | 낮에 술 → 술 라벨 + 시각 | [표준 64203](https://stdict.korean.go.kr/search/searchView.do?word_no=64203&searchKeywordTo=3) | 술병만 찍히는 `wine_bottle`은 「마신다」가 약해 뺐다. 라벨 목록은 앞선 조사 「술자리」와 같다 |
| **밤술** | 밤에 마시는 술 | 밤에 마시는 술 | 낮술과 같음 | 20:00–03:59(밤 칸) | 밤에 술 → 술 라벨 + 시각 | [표준 431605](https://stdict.korean.go.kr/search/searchView.do?word_no=431605&searchKeywordTo=3) | 사전이 낮술과 서로 참고 어휘로 묶는다. 술자리와 나누는 법은 1-9 |

### 1-2. 먹을 것
| 단어 | 사전 뜻 요약 | 앱용 한 줄 뜻 | 붙일 라벨 | 시각·날씨·기온 조건 | 주장하는 사실 → 확인 수단 | 출처 | 비고 |
|---|---|---|---|---|---|---|---|
| **★늦아침** | 「1」 아침이 된 지 한참 지난 때의 아침 「2」 아침 식사 때가 지나서 늦게 먹는 아침밥 | 아침때가 지나 늦게 먹는 아침밥 | `food`·`bread`·`croissant`·`bagel`·`white_bread`·`pastry`·`muffin`·`scone`·`pancake`·`waffle`·`fried_egg`·`omelet`·`scrambled_eggs`·`cereal`·`oatmeal`·`yogurt`·`sandwich`·`coffee` | 10:00–11:59 | 늦은 아침 → 시각(「1」 뜻만으로도 참) + 먹을거리 라벨 | [표준 535702](https://stdict.korean.go.kr/search/searchView.do?word_no=535702&searchKeywordTo=3) | 「아침결」 용례에 「열 시가 좀 넘었을 아침결」이 있어 10시대를 아침으로 보는 근거가 된다. 앞선 조사 「밥때」와는 시각으로 나눈다 |
| **늦저녁** | 「1」 저녁이 된 지 한참 지난 때의 저녁 「2」 저녁 식사 때가 지나서 늦게 먹는 저녁밥 | 저녁때가 지나 늦게 먹는 저녁밥 | `food`·`rice`·`soup`·`ramen`·`pasta`·`spaghetti`·`pizza`·`pepperoni`·`steak`·`salad`·`sushi`·`curry`·`hamburger`·`fried_chicken`·`stir_fry`·`dumpling`·`meat`·`plate`·`bowl`·`chopsticks` | 20:00–21:59 | 늦은 저녁 → 시각 + 먹을거리 라벨 | [표준 71986](https://stdict.korean.go.kr/search/searchView.do?word_no=71986&searchKeywordTo=3) | 지금 「끼니」는 밤 칸(20–03:59) 전체에 붙는다. 20–21시는 늦저녁, 22시부터는 밤참으로 넘기길 제안 |
| **★단것** | 설탕류, 과자류 따위의 맛이 단 음식물 | 설탕이나 과자처럼 맛이 단 먹을거리 | `cake`·`cake_regular`·`birthday_cake`·`wedding_cake`·`cupcake`·`cheesecake`·`brownie`·`tiramisu`·`donut`·`cookie`·`chocolate`·`chocolate_chip`·`candy`·`candy_other`·`candy_cane`·`lollipop`·`marshmallow`·`caramel`·`taffy`·`ice_cream`·`frozen_dessert`·`popsicle`·`pudding`·`dessert`·`baklava`·`crepe`·`flan`·`jello`·`gingerbread`·`fruitcake`·`strudel` | 없음 | 단 음식이 있다 → 케이크·과자·사탕 라벨 | [표준 410064](https://stdict.korean.go.kr/search/searchView.do?word_no=410064&searchKeywordTo=3) | 지금 「주전부리」(`dessert`·`cake`·`bread`·`fruit`)와 라벨이 겹친다. 나누는 법은 1-9 |
| **★여름나기** | 여름을 지내어 넘김. 또는 그런 일 | 여름을 지내어 넘기는 일 | `ice_cream`·`popsicle`·`frozen_dessert`·`ice`·`smoothie`·`juice`·`milkshake`·`watermelon`·`electric_fan` | 6–8월 + 기온 ≥ 28°C(제안값) | 더운 여름을 시원한 것으로 난다 → 달 + 기온 + 라벨 | [표준 535350](https://stdict.korean.go.kr/search/searchView.do?word_no=535350&searchKeywordTo=3) | 사전 참고 어휘에 봄나기·가을나기·겨울나기 |
| **겨울나기** | 겨울을 지내어 넘김. 또는 그런 일(≒겨우살이·월동) | 겨울을 지내어 넘기는 일 | `soup`·`ramen`·`kettle`·`teapot`·`tea_drink`·`thermos`·`fireplace` | 12–2월 + 기온 ≤ 5°C(제안값) | 추운 겨울을 따뜻한 것으로 난다 → 달 + 기온 + 라벨 | [표준 15864](https://stdict.korean.go.kr/search/searchView.do?word_no=15864&searchKeywordTo=3) | 같은 뜻 「겨우살이」는 기생 식물 이름과 꼴이 같아 피했다 |
| **제철** | 알맞은 시절(≒철) | 그것이 한창 나는 알맞은 때 | 과일 라벨마다 달: `strawberry` 1–4월, `watermelon` 6–8월, `peach` 7–9월, `grape` 8–10월, `chestnut` 9–10월, `persimmon` 10–11월, `mandarine` 11–2월 | 과일별 달(**제안값, 출처 없음**) | 그 과일이 지금 제철 → 과일 라벨 + 찍은 달 | [표준 301227](https://stdict.korean.go.kr/search/searchView.do?word_no=301227&searchKeywordTo=3) | 달 표는 농림축산식품부 제철 농산물 달력과 대조해야 한다(요확인). `fruit`·`apple`·`banana`처럼 철을 가리기 어려운 라벨은 뺐다. 동형어 제철2(製鐵)·제철3(蹄鐵)이 있지만 제철1은 원어·어원 모두 한자 없음 |
| 국물 *(보조)* | 「1」 국, 찌개 따위의 음식에서 건더기를 제외한 물 | 국이나 찌개에서 건더기를 뺀 물 | `soup`·`ramen` | 없음 | 국물이 있다 → 국·라면 라벨 | [표준 396809](https://stdict.korean.go.kr/search/searchView.do?word_no=396809&searchKeywordTo=3) | 정직하지만 일상어라 밋밋하다. 「2」는 부수입을 속되게 이르는 뜻 |

### 1-3. 읽고 쓰기
| 단어 | 사전 뜻 요약 | 앱용 한 줄 뜻 | 붙일 라벨 | 시각·날씨·기온 조건 | 주장하는 사실 → 확인 수단 | 출처 | 비고 |
|---|---|---|---|---|---|---|---|
| **★갈피** | 「1」 겹치거나 포갠 물건의 하나하나의 사이. 또는 그 틈 | 포개진 책장 한 장 한 장의 사이 | `book`·`magazine`·`printed_page`·`newspaper` | 없음 | 포갠 종이가 있다 → 책·잡지 라벨 | [표준 387602](https://stdict.korean.go.kr/search/searchView.do?word_no=387602&searchKeywordTo=3) | 「2」(갈피를 못 잡다)로 읽힐 수 있어 앱 뜻 줄로 「1」을 붙잡아야 한다. 「노래갈피」의 그 갈피. 「책갈피」는 冊이라 안 됨 |
| **★적바림** | 나중에 참고하기 위하여 글로 간단히 적어 둠. 또는 그런 기록 | 나중에 보려고 간단히 적어 둔 글 | `sticky_note`, 또는 `handwriting` **그리고** `pen`·`calendar`·`document` | 없음 | 짧게 적어 둔 메모 → 포스트잇 라벨, 또는 손글씨 + 필기구·달력·서류 | [표준 478283](https://stdict.korean.go.kr/search/searchView.do?word_no=478283&searchKeywordTo=3) | 손글씨만으로는 긴 편지·일기일 수 있어 AND로 묶었다. 낯선 말이라 뜻 줄이 꼭 같이 보여야 한다 |
| **★글월** | 「1」 글이나 문장 「2」 '편지'를 달리 이르는 말 | 편지를 달리 이르는 말 | `envelope` **그리고** `handwriting` | 없음 | 손으로 쓴 편지 → 봉투 + 손글씨 | [표준 47239](https://stdict.korean.go.kr/search/searchView.do?word_no=47239&searchKeywordTo=3) | 어원 「글+발」, 한자 없음. `envelope` 하나만이면 고지서·청첩장에도 붙어 넓다. 「편지」는 便紙라 안 됨 |
| **★나날** | 계속 이어지는 하루하루의 날들 | 이어지는 하루하루의 날들 | `calendar` | 없음 | 날들이 이어져 있다 → 달력 라벨 | [표준 406632](https://stdict.korean.go.kr/search/searchView.do?word_no=406632&searchKeywordTo=3) | 어원 「날+날」 |
| **글씨** | 「1」 쓴 글자의 모양 | 손으로 쓴 글자의 모양 | `handwriting` | 없음 | 손으로 쓴 글자 → `handwriting` | [표준 45600](https://stdict.korean.go.kr/search/searchView.do?word_no=45600&searchKeywordTo=3) | 어원 「글+스-(쓰다)+-이」. 「손글씨」는 우리말샘에 「손 글씨」 두 단어로만 있다. 「글자」는 字라 안 됨 |
| **길잡이** | 「1」 길을 인도해 주는 사람이나 사물 | 길을 이끌어 주는 것 | `map`·`compass` | 없음 | 길을 안내하는 물건 → 지도·나침반 라벨 | [표준 403349](https://stdict.korean.go.kr/search/searchView.do?word_no=403349&searchKeywordTo=3) | 같은 뜻 「길라잡이」는 어원 「길나장이←羅將」이라 제외 |
| 읽을거리 *(보조)* | 읽을 만한 책이나 문건. 또는 그 내용 | 읽을 만한 책이나 글 | `book`·`magazine`·`newspaper` | 없음 | 읽을 것이 있다 → 책 라벨 | [표준 265862](https://stdict.korean.go.kr/search/searchView.do?word_no=265862&searchKeywordTo=3) | 밋밋하다. 「만한」이라는 가벼운 평가가 들어 있다 |
| 물감 *(보조)* | 「2」 그림을 그리는 데에 쓰는 화구(=그림물감) | 그림을 그릴 때 색을 내는 재료 | `paintbrush`·`easel` | 없음 | 그림 도구가 있다 → 붓·이젤 라벨 | [표준 124634](https://stdict.korean.go.kr/search/searchView.do?word_no=124634&searchKeywordTo=3) | 밋밋하다. 동형어 물감1(감의 한 품종). 「붓질」은 붓←筆이라 제외 |

### 1-4. 일하는 책상
| 단어 | 사전 뜻 요약 | 앱용 한 줄 뜻 | 붙일 라벨 | 시각·날씨·기온 조건 | 주장하는 사실 → 확인 수단 | 출처 | 비고 |
|---|---|---|---|---|---|---|---|
| **일터** | 「1」 일을 하는 곳 | 일을 하는 곳 | `cubicle`·`whiteboard`·`flipchart`, 또는 `computer_monitor` **그리고** `computer_keyboard`, 또는 `laptop` **그리고** `document` | **평일** 09:00–17:59(제안값) | 일하는 자리 → 사무 라벨 + 평일 근무 시각 | [표준 265834](https://stdict.korean.go.kr/search/searchView.do?word_no=265834&searchKeywordTo=3) | 집 책상에서 게임하는 중일 수도 있어 약간 넓다. 밤 노트북에 붙일 말로 본 「밤일」은 「2」 뜻(성교의 완곡어) 때문에 제외 |
| 짬 *(지금 목록, 개정)* | 「1」 어떤 일에서 손을 떼거나 다른 일에 손을 댈 수 있는 겨를 | (지금 그대로) | (`coffee`·`mug`·`cup`·`tea_drink`·`dessert`·`cookie`·`donut`) **그리고** (`laptop`·`computer`·`computer_monitor`·`document`) | **평일** 10:00–16:59(제안값) | 일하던 자리에서 마실 것을 든 순간 → 라벨 AND + 평일 낮 | [표준 486750](https://stdict.korean.go.kr/search/searchView.do?word_no=486750&searchKeywordTo=3) | 「손을 뗐다」는 여전히 추정이다. 2절 참고 |

### 1-5. 불·빛
| 단어 | 사전 뜻 요약 | 앱용 한 줄 뜻 | 붙일 라벨 | 시각·날씨·기온 조건 | 주장하는 사실 → 확인 수단 | 출처 | 비고 |
|---|---|---|---|---|---|---|---|
| **★불그림자** | 「1」 어떤 물체가 불빛을 가려서 생긴 그림자 「2」 물이나 유리 따위에 비친 불빛 | 유리나 물에 비친 불빛 | (`lamp`·`candle`·`candlestick`·`lantern`·`light_bulb`·`chandelier`) **그리고** (`window`·`drinking_glass`) | 밤(20:00–03:59), 또는 저녁 칸 중 해 진 뒤(태양 고도 < 0°) | 바깥이 어둡고, 켠 불과 유리가 함께 있다 → 라벨 AND + 시각 | [표준 435935](https://stdict.korean.go.kr/search/searchView.do?word_no=435935&searchKeywordTo=3) | 어두울 때 창유리는 안쪽 불빛을 비추지만, 그 반사가 사진에 찍혔는지까지는 모른다. 약간 넓다. 지금 「불빛」은 그대로 두고, 유리 라벨이 같이 잡힐 때만 불그림자도 후보에 오르게 |

### 1-6. 꽃·식물
새로 넣을 고유어를 찾지 못했다. 꽃병(꽃甁)·화분(花盆)은 한자가 섞였고, 「꽃내음」은 사전에 한 단어로 없으며, 「잎새」는 「나무의 잎사귀」라 화분의 풀에는 거짓일 수 있고, 선인장의 「가시」는 동형어(가시2 = 구더기)와 날 선 어감이 걸린다. 대신 앞선 조사의 말에 라벨을 넓히길 권한다.
- **꽃꽂이**(앞선 조사, `flower_arrangement`): 사전 뜻이 「꽃병이나 수반에 꽂아」이므로 `vase` **그리고** 꽃 라벨(`flower`·`rose`·`tulip`·`daisy`·`lily`·`orchid`·`sunflower`)도 정직하다.
- **푸나무**(앞선 조사, `plant`·`decorative_plant`·`vegetation`): 책상 위 `cactus`·`bonsai`를 더해도 「풀과 나무」에 들어간다.

### 1-7. 놀이·소품
| 단어 | 사전 뜻 요약 | 앱용 한 줄 뜻 | 붙일 라벨 | 시각·날씨·기온 조건 | 주장하는 사실 → 확인 수단 | 출처 | 비고 |
|---|---|---|---|---|---|---|---|
| **★한판** | 「1」 한 번 벌이는 판 | 한 번 벌이는 놀이판 | `board_game`·`chess`·`play_card`·`poker`·`backgammon`·`domino`·`dice`·`videogame`·`gamepad` | 없음 | 놀이판이 벌어졌다 → 놀이 도구 라벨 | [표준 504757](https://stdict.korean.go.kr/search/searchView.do?word_no=504757&searchKeywordTo=3) | 「2」 유도 판정, 관용구 「한판 뜨다」(속된 말)가 있어 뜻 줄로 「1」을 붙잡아야 한다 |
| **★옛것** | 오래된, 옛날의 것 | 오래된 옛날의 것 | `typewriter`·`cassette`·`diskette` | 없음 | 오래된 물건 → 지금은 거의 새로 만들지 않는 물건 라벨 | [표준 239575](https://stdict.korean.go.kr/search/searchView.do?word_no=239575&searchKeywordTo=3) | 「손때」의 정직한 대체(2절). `record`·`turntable`은 새로 찍어 내는 LP가 많고, `camera`는 대부분 새것이라 뺐다 |
| **꾸러미** | 「1」 꾸리어 싼 물건(용례 「선물 꾸러미」) | 꾸려서 싼 물건 | `gift` | 없음 | 싸 놓은 물건 → `gift` | [표준 404344](https://stdict.korean.go.kr/search/searchView.do?word_no=404344&searchKeywordTo=3) | 「선물」은 膳物이라 안 됨 |
| **놀잇감** | 놀이 또는 아동 교육 현장 따위에서 활용되는 물건이나 재료 | 놀이에 쓰는 물건 | `toy`·`stuffed_animals`·`doll`·`figurine`·`blocks`·`vehicle_toy`·`train_toy`·`puzzles`·`jigsaw` | 없음 | 놀이 물건 → 장난감 라벨 | [표준 67026](https://stdict.korean.go.kr/search/searchView.do?word_no=67026&searchKeywordTo=3) | 앞선 조사 「장난감」(**아이들이** 가지고 노는 여러 가지 물건)과 라벨이 같아 둘 중 하나만. 어른 방의 인형·피규어에는 「아이들이」가 없는 놀잇감이 더 정직하다(Tabber 사진의 `toy`·`stuffed_animals`) |

### 1-8. 함께 있는 자리
| 단어 | 사전 뜻 요약 | 앱용 한 줄 뜻 | 붙일 라벨 | 시각·날씨·기온 조건 | 주장하는 사실 → 확인 수단 | 출처 | 비고 |
|---|---|---|---|---|---|---|---|
| **잔치** | 「1」 기쁜 일이 있을 때에 음식을 차려 놓고 여러 사람이 모여 즐기는 일 | 기쁜 날 음식을 차려 놓고 여럿이 모여 즐기는 일 | (`birthday_cake`·`wedding_cake`·`celebration`) **그리고** `people` | **사람 수 ≥ 2** | 기쁜 일·차린 음식·여러 사람 → 케이크 라벨 + `people` + 사람 수 | [표준 478212](https://stdict.korean.go.kr/search/searchView.do?word_no=478212&searchKeywordTo=3) | 어원란에 한자 없음(동형어 잔치3은 殘置). 지금 「모꼬지」(놀이나 잔치 또는 그 밖의 일로 여러 사람이 모이는 일)와 거의 같은 자리라, 더 쉬운 잔치 하나만 남기길 권함 |
| **한자리** | 「1」 같은 자리(용례 「온 가족이 한자리에 모이다」) | 여럿이 함께 앉은 같은 자리 | `people` **그리고** (`food`·`plate`·`bowl`·`drinking_glass`·`cup`·`coffee`·술 라벨) | **사람 수 ≥ 2** | 여럿이 한 상에 → `people` + 사람 수 + 상 위 라벨 | [표준 502120](https://stdict.korean.go.kr/search/searchView.do?word_no=502120&searchKeywordTo=3) | 말벗의 정직한 대체(2절). 「2」 직위라는 뜻이 있어 뜻 줄로 붙잡아야 한다. 사람 수 신호가 없으면 넣지 말 것 |

### 1-9. 앞선 조사·지금 목록의 말과 나눠 쓰기
| 장면 | 앞선 조사·지금 목록 | 이번 후보 | 나누는 기준 |
|---|---|---|---|
| 밥 먹는 때 | 밥때(07–14:59·17–19:59), 밤참(21–02 권장), 끼니(지금) | 늦아침 10–11:59, 늦저녁 20–21:59 | 겹쳐도 둘 다 참이라 거짓은 없다. 밤참을 22–03:59로 당기면 20–21시는 늦저녁, 22시부터는 밤참으로 깔끔하게 갈린다. 끼니에서 밤 칸을 빼자는 앞선 조사 제안은 그대로 |
| 술 | 술자리(술 라벨) | 낮술 11–16:59, 밤술 20–03:59 | 술자리를 `people` **그리고** 술 라벨로 좁히면, 사람이 안 찍힌 술은 시각에 따라 낮술·밤술. 17–19시에 혼자 마시는 술은 술자리 「또는 술상을 베푼 자리」 뜻으로도 거짓은 아니라 술자리만 남겨도 됨 |
| 단 음식 | 주전부리(지금), 군것질(앞선 조사, 오후·밤) | 단것 | 단것은 **대상**(단 음식이 있다)이라 시각과 상관없다. 군것질은 **행동**(끼니 밖에 먹는다)이라 끼니 아닌 시각만. 주전부리는 사전 「1」이 「자꾸 먹음. 또는 그런 입버릇」이라 사진으로 확인이 안 되고 「2」(심심풀이로 먹는 음식)만 정직하다. 「3」에 속된 성적 뜻도 있다 — 지금 뜻 줄을 「2」 쪽으로 다듬을지 Tabber 판단 |
| 꽃 | 꽃꽂이(앞선 조사) | — | `vase` 그리고 꽃 라벨로 넓힘(1-6) |
| 장난감 | 장난감(앞선 조사) | 놀잇감 | 같은 라벨이라 하나만 |
| 불 | 불빛(지금) | 불그림자 | 유리 라벨이 같이 잡힐 때만 불그림자 |

## 2. 손때·말벗·짬·겨를 판정
| 말 | 사전 뜻(근거) | 지금 붙는 라벨 | 정직하게 붙일 수 있는 조합 | 판정 |
|---|---|---|---|---|
| **손때** | 「1」 **오랫동안** 쓰고 매만져서 길이 든 흔적 「2」 손을 대어 건드리거나 만져서 생긴 때 「3」 손에 끼인 때 ([표준 194986](https://stdict.korean.go.kr/search/searchView.do?word_no=194986&searchKeywordTo=3)) | `book`·`desk`·`table`·`wood_processed` — 오래됐는지 알려 주는 라벨이 하나도 없고, 셋은 배경 라벨 | **없음.** 「오래」를 말해 주는 라벨도, 길든 「흔적」을 보는 라벨도 없다. 오래된 물건 라벨(`typewriter`·`cassette`·`diskette`)도 「손으로 길들였다」까지는 말하지 못한다. 게다가 「2」「3」은 더러운 때라서 잘못 읽히면 흠이 된다 | **빼기.** 오래된 물건엔 「옛것」(1-7) |
| **말벗** | 더불어 이야기할 만한 **친구**(=말동무) ([표준 111410](https://stdict.korean.go.kr/search/searchView.do?word_no=111410&searchKeywordTo=3)) | `people` | **없음.** 친구 사이인지, 이야기를 나누는지 둘 다 사진으로 모른다. `people`은 혼자 찍힌 사진과 지나가는 사람에게도 붙는다. 사람 수를 세게 되어도 「친구」는 끝까지 확인이 안 된다 | **빼기.** 여럿이 한 상이면 「한자리」(사람 수 2+), 술이면 「술자리」(앞선 조사), 케이크면 「잔치」 |
| **짬** | 「1」 어떤 일에서 손을 떼거나 다른 일에 손을 댈 수 있는 겨를 ([표준 486750](https://stdict.korean.go.kr/search/searchView.do?word_no=486750&searchKeywordTo=3)) | `laptop`·`computer`·`desk`·`cup` | 노트북만 있으면 오히려 일하는 중이고, `desk`는 배경이며, 주말·밤에도 붙는다. 그나마 가까운 조합은 마실 것·주전부리 **그리고** 일거리(`laptop`·`computer`·`computer_monitor`·`document`) + **평일 10–16:59**. 그래도 「손을 뗐다」는 추정이다(사진을 찍으려 잠깐 손을 멈춘 것까지만 맞다) | **조건을 좁혀 남기거나 빼기 — Tabber 결정.** 남긴다면 1-4의 조건으로만 |
| **겨를** | 「의존 명사」 ((어미 「-을」 뒤에 쓰여)) 어떤 일을 하다가 생각 따위를 다른 데로 돌릴 수 있는 시간적인 여유 ([표준 395927](https://stdict.korean.go.kr/search/searchView.do?word_no=395927&searchKeywordTo=3)) | `laptop`·`computer`·`book` | **없음.** **의존 명사**라서 「쉴 겨를」처럼 앞말 없이 홀로 쓸 수 없다. 뜻은 짬과 같고, 사전에 보이는 용례 넷이 모두 「~할 겨를이 없다」 꼴이다 | **빼기.** (앞선 조사 C절은 짬과 묶어 「`cup`·`coffee`만 남기거나 빼기」로 적었는데, 의존 명사라는 점은 이번에 새로 확인했다) |

Tabber 사진 20장 가까운 책상·식탁 사진 중 손때 7장, 짬·겨를 7장이 이 네 말로 뭉뚱그려졌다. 아래 예시 8장으로 돌려 보면 손때 7번 → 0번, 말벗 2번 → 0번, 짬·겨를 3번 → 짬(개정) 1번으로 줄고, 그 자리를 물건과 때가 함께 맞는 말이 채운다.

## 3. Tabber 책상·식탁 라벨 조합 예시
Tabber 사진에 실제로 잡힌 라벨로 그럴듯하게 꾸렸다. **\*** 는 지금 어휘(단어들이 쓰는 라벨)에 없어 정밀도 90%를 넘어야만 잡히는 라벨이다. 이번 후보가 들어가 어휘가 되면 70% 문턱으로 잡힐 수 있다고 **가정**했고, 「지금 후보」 칸은 \* 라벨을 뺀 채로 돌렸다. `coffee`·`book`·`cup`·`candle`·`cake`는 지금도 어휘에 있다(목축임·손때·겨를·짬·불빛·주전부리).

「후보」는 `WordPicker.candidates`가 돌려주는 집합이다. 실제로 붙는 한 단어는 그중 `fnv1a(seed:id)`가 가장 작은 것이라 사진마다 다르다(Apple Intelligence 고르기는 `WordAssistant`에서 기본 꺼짐). 「이번 후보를 넣은 뒤」는 손때·말벗·겨를을 빼고 짬을 1-4 조건으로 바꾼 목록이다. 굵은 글씨가 이번 후보다.

| # | 장면 · 찍은 때 | 잡힌 라벨 | 지금 후보 | 이번 후보를 넣은 뒤 | 앞선 조사 말도 넣으면 더 붙는 것 |
|---|---|---|---|---|---|
| 1 | 평일 오후, 노트북 옆 커피 · 9/15(화) 14:20 흐림 24°C | `structure`·`wood_processed`·`furniture`·`table`·`computer`·`laptop`·`consumer_electronics`·`cord`·`eyeglasses`·`optical_equipment`·`cup`·`coffee`·`mug`\* | 목축임·손때·짬·겨를 | 목축임·**내음**·짬(개정) | — |
| 2 | 밤, 스탠드 켠 책상과 창 · 10/2(금) 23:40 맑음 18°C | `structure`·`wood_processed`·`furniture`·`table`·`computer`·`laptop`·`lamp`·`light`·`window`·`portal`·`curtain`·`eyeglasses`·`optical_equipment`·`book` | 불빛·빛살·손때·짬·겨를 | 불빛·빛살·**갈피**·**불그림자**·읽을거리 | — |
| 3 | 비 오는 토요일 저녁, 피자와 맥주 · 9/26(토) 20:30 비 17°C | `table`·`tableware`·`utensil`·`plate`·`food`·`pepperoni`·`drinking_glass`·`bottle`·`container`·`people`·`adult`·`pizza`\*·`beer`\* | 끼니·말벗·손때 | 끼니·**밤술**·**늦저녁**·한자리(사람 수 2+일 때만) | 술자리·그릇 |
| 4 | 토요일 늦은 아침, 빵과 커피 · 5/16(토) 10:40 맑음 21°C | `table`·`tableware`·`plate`·`food`·`drinking_glass`·`window`·`curtain`·`light`·`bread`·`coffee`·`croissant`\* | 볕바라기·새참·곁두리·주전부리·끼니·목축임·빛살·햇발·손때 | 손때만 빠지고 나머지 그대로 + **내음**·**늦아침** | 밥때 |
| 5 | 겨울밤 생일 케이크 · 12/18(금) 21:10 맑음 −3°C | `table`·`tableware`·`plate`·`food`·`people`·`adult`·`candle`·`cake`·`birthday_cake`\* | 주전부리·끼니·말벗·불빛·손때 | 주전부리·끼니·불빛·**단것**·**늦저녁**·잔치·한자리(둘 다 사람 수 2+일 때만) | 밤참(앞선 조사의 21시 시작을 따를 때) |
| 6 | 평일 오후, 포스트잇과 손글씨 · 11/11(수) 15:30 흐림 12°C | `structure`·`wood_processed`·`furniture`·`table`·`laptop`·`computer`·`book`·`handwriting`\*·`pen`\*·`sticky_note`\* | 손때·짬·겨를 | **적바림**·**글씨**·**갈피**·읽을거리 (마실 것이 없어 짬(개정)은 안 붙음) | — |
| 7 | 여름 일요일 한낮, 선반 위 인형 · 8/9(일) 13:00 맑음 31°C | `structure`·`furniture`·`toy`·`stuffed_animals`·`light`·`window`·`figurine`\* | 빛살·햇발 (`toy`·`stuffed_animals`를 쓰는 단어가 없다) | 빛살·햇발·**놀잇감** | 장난감 |
| 8 | 한겨울 밤 라면 · 1/14(목) 22:30 맑음 −6°C | `table`·`tableware`·`utensil`·`bowl`·`food`·`ramen`\*·`soup`\*·`chopsticks`\* | 끼니·손때 | 끼니·**겨울나기**·국물 | 밤참·그릇 |

읽을 점
- 지금은 8장 중 7장에 손때가 후보로 오른다. `table`·`wood_processed` 하나면 충분하기 때문이다.
- 예시 7처럼 Tabber 사진에 실제로 있는 `toy`·`stuffed_animals`는 지금 어떤 단어도 쓰지 않아 창·빛 말로 넘어간다.
- 예시 3·5의 한자리·잔치는 사람 수 신호(0절)가 생기기 전엔 넣지 말아야 한다. 신호 없이 넣으면 말벗과 같은 거짓말이 된다.
- 예시 8의 「끼니」(22:30 라면)는 앞선 조사가 짚은 밤 칸 문제 그대로다.

## 4. 미확인·제외
### 미확인 — 사전에 한 단어로 없어 추천하지 않음
| 말 | 확인 결과 |
|---|---|
| 꽃내음 | 표준국어대사전에 없음. 우리말샘에 「꽃 내음」(두 단어, 품사 없음)으로만 있음 |
| 마실거리 | 표준에 없음. 우리말샘에 「마실 거리」(두 단어)로만 있음 |
| 아침녘 | 두 사전 모두 없음 |
| 한모금 | 표준에 없음. 우리말샘엔 전문가 감수 0, 참여자 제안만 2 |
| 꽃빛·둘레상 | 표준에 없음. 우리말샘에도 그 꼴은 없음 |
| 쉼 | 표준 표제어 없음. 우리말샘엔 「수염」「헤엄」「숨」의 **방언**만 |
| 낮밥 | 표준에 없음. 우리말샘: 「낮잠」의 **방언**(함경) |
| 새벽참 | 표준에 없음. 우리말샘: 「새벽녘」의 **북한어** |
| 날적이 | 표준에 없음. 우리말샘에 있지만 「집단이나 모임에서 공유하기 위하여 쓰는 일기」라 혼자 쓴 손글씨에는 거짓 |
| 달임 | 표준에 없음. 우리말샘: 「약재 따위에 물을 부어 우러나도록 끓임」 — 차에는 어긋남 |

### 제외 — 한자가 섞임
| 말 | 근거 | 출처 |
|---|---|---|
| 촛불 | 어원 「쵸+-ㅅ+블」, 그 「초」의 어원이 「쵸＜燭」 | [표준 489101](https://stdict.korean.go.kr/search/searchView.do?word_no=489101&searchKeywordTo=3), [초 488934](https://stdict.korean.go.kr/search/searchView.do?word_no=488934&searchKeywordTo=3) |
| 등불 | 燈불 | [표준 95050](https://stdict.korean.go.kr/search/searchView.do?word_no=95050&searchKeywordTo=3) |
| 심지 | 心지 | [표준 455676](https://stdict.korean.go.kr/search/searchView.do?word_no=455676&searchKeywordTo=3) |
| 붓·붓질 | 붓의 어원 「붇＜筆」 | [표준 435018](https://stdict.korean.go.kr/search/searchView.do?word_no=435018&searchKeywordTo=3) |
| 길라잡이 | 어원 「길나장이←길+나장(羅將)+-이」 | [표준 403342](https://stdict.korean.go.kr/search/searchView.do?word_no=403342&searchKeywordTo=3) |
| 숭늉 | 어원 「＜슝농＜슉＜熟冷」 | [표준 196664](https://stdict.korean.go.kr/search/searchView.do?word_no=196664&searchKeywordTo=3) |
| 찻잔·술잔 | 찻盞·술盞 | [표준 484306](https://stdict.korean.go.kr/search/searchView.do?word_no=484306&searchKeywordTo=3), [449595](https://stdict.korean.go.kr/search/searchView.do?word_no=449595&searchKeywordTo=3) |
| 책상·식탁·탁자 | 冊床·食卓·卓子 | [표준 483676](https://stdict.korean.go.kr/search/searchView.do?word_no=483676&searchKeywordTo=3), [449219](https://stdict.korean.go.kr/search/searchView.do?word_no=449219&searchKeywordTo=3), [497530](https://stdict.korean.go.kr/search/searchView.do?word_no=497530&searchKeywordTo=3) |
| 공책·편지·쪽지·글자 | 空冊·便紙·쪽紙·글字 | [표준 31297](https://stdict.korean.go.kr/search/searchView.do?word_no=31297&searchKeywordTo=3), [499292](https://stdict.korean.go.kr/search/searchView.do?word_no=499292&searchKeywordTo=3), [483009](https://stdict.korean.go.kr/search/searchView.do?word_no=483009&searchKeywordTo=3), [404056](https://stdict.korean.go.kr/search/searchView.do?word_no=404056&searchKeywordTo=3) |
| 꽃병·화분 | 꽃甁·花盆 | [표준 55661](https://stdict.korean.go.kr/search/searchView.do?word_no=55661&searchKeywordTo=3), [376433](https://stdict.korean.go.kr/search/searchView.do?word_no=376433&searchKeywordTo=3) |
| 안경·선물·생일 | 眼鏡·膳物·生日 | [표준 451609](https://stdict.korean.go.kr/search/searchView.do?word_no=451609&searchKeywordTo=3), [444462](https://stdict.korean.go.kr/search/searchView.do?word_no=444462&searchKeywordTo=3), [177402](https://stdict.korean.go.kr/search/searchView.do?word_no=177402&searchKeywordTo=3) |
| 접시 | 어원 「뎝시＜楪子」(앞선 조사) | [표준 475906](https://stdict.korean.go.kr/search/searchView.do?word_no=475906&searchKeywordTo=3) |

### 제외 — 사진으로 확인할 수 없거나, 뜻이 어긋나거나, 동형어가 걸림
| 말 | 왜 | 출처 |
|---|---|---|
| 김 | 김1 「액체가 열을 받아서 기체로 변한 것」은 라면·주전자에 맞지만, 김3(해초)과 꼴이 같아 음식 사진에선 해초로 읽힌다 | [표준 399859](https://stdict.korean.go.kr/search/searchView.do?word_no=399859&searchKeywordTo=3) |
| 밤일 | 「2」 성교의 완곡어 | [표준 135470](https://stdict.korean.go.kr/search/searchView.do?word_no=135470&searchKeywordTo=3) |
| 얼음물 | 「얼음을 넣은 물」 — 얼음 든 잔이 물인지 아이스커피·탄산인지 모른다. 「이 라벨이 있으면 빼기」 조건이 생기면 다시 볼 만함 | [표준 226453](https://stdict.korean.go.kr/search/searchView.do?word_no=226453&searchKeywordTo=3) |
| 입가심 | 「입안을 개운하게 가시어 냄」 — 밥 먹은 뒤라는 순서를 사진 한 장으로 모른다 | [표준 273155](https://stdict.korean.go.kr/search/searchView.do?word_no=273155&searchKeywordTo=3) |
| 햇것 | 「당해에 처음 난 물건」 — 처음인지 모른다 | [표준 502993](https://stdict.korean.go.kr/search/searchView.do?word_no=502993&searchKeywordTo=3) |
| 한입 | 「입에 음식물 따위가 가득 찬 상태」 — 행동 | [표준 367556](https://stdict.korean.go.kr/search/searchView.do?word_no=367556&searchKeywordTo=3) |
| 밥심 | 「밥을 먹고 나서 생긴 힘」 — 확인 불가 | [표준 516471](https://stdict.korean.go.kr/search/searchView.do?word_no=516471&searchKeywordTo=3) |
| 단물 | 민물·단맛 나는 물·알짜의 비유, 동형어(본래 색)까지 한 꼴 | [표준 410492](https://stdict.korean.go.kr/search/searchView.do?word_no=410492&searchKeywordTo=3) |
| 곁들이 | 「주된 음식 옆에」 — 무엇이 주인지 모른다 | [표준 21764](https://stdict.korean.go.kr/search/searchView.do?word_no=21764&searchKeywordTo=3) |
| 끼니때 | 밥때와 같은 뜻 | [표준 407762](https://stdict.korean.go.kr/search/searchView.do?word_no=407762&searchKeywordTo=3) |
| 차림 | 「옷이나 물건 따위를 입거나 꾸려서 갖춘 상태」 — 상차림 뜻이 아님 | [표준 319701](https://stdict.korean.go.kr/search/searchView.do?word_no=319701&searchKeywordTo=3) |
| 먹거리·먹을거리 | 정직하지만 밋밋. 자리가 비면 보조로만 | [표준 113843](https://stdict.korean.go.kr/search/searchView.do?word_no=113843&searchKeywordTo=3), [113002](https://stdict.korean.go.kr/search/searchView.do?word_no=113002&searchKeywordTo=3) |
| 일감·일거리 | 「일을 하여 돈을 벌 거리」 — 확인 불가 | [표준 264493](https://stdict.korean.go.kr/search/searchView.do?word_no=264493&searchKeywordTo=3), [467863](https://stdict.korean.go.kr/search/searchView.do?word_no=467863&searchKeywordTo=3) |
| 말미 | 「매인 사람이 다른 일로 얻는 겨를」(≒휴가) — 확인 불가. 동형어 말미2(末尾) | [표준 113026](https://stdict.korean.go.kr/search/searchView.do?word_no=113026&searchKeywordTo=3) |
| 일손 | 「일하는 손」 — 손이 찍혔는지 모르고, 「일손을 놓다」 관용이 먼저 떠오름 | [표준 476458](https://stdict.korean.go.kr/search/searchView.do?word_no=476458&searchKeywordTo=3) |
| 빛무리 | 『천문』 구름이 해·달을 가릴 때 그 둘레에 생기는 빛의 테 — 전등에는 거짓 | [표준 166821](https://stdict.korean.go.kr/search/searchView.do?word_no=166821&searchKeywordTo=3) |
| 밤빛 | 밤빛1(밤의 느낌을 나타내는 빛)과 밤빛2(밤색)가 같은 꼴 | [표준 136286](https://stdict.korean.go.kr/search/searchView.do?word_no=136286&searchKeywordTo=3) |
| 어둠 | 불 켠 사진에 「어두운 상태」는 어긋남 | [표준 456374](https://stdict.korean.go.kr/search/searchView.do?word_no=456374&searchKeywordTo=3) |
| 고요 | 「조용하고 잠잠한 상태」 — 소리는 사진으로 모름 | [표준 394913](https://stdict.korean.go.kr/search/searchView.do?word_no=394913&searchKeywordTo=3) |
| 가시 | 선인장엔 맞지만 가시2(구더기)·「2」 생선 가시가 같은 꼴이고 어감이 날카롭다 | [표준 389589](https://stdict.korean.go.kr/search/searchView.do?word_no=389589&searchKeywordTo=3) |
| 잎새 | 「나무의 잎사귀」(2015 표준어) — 화분 풀이 나무인지 모름. `bonsai`엔 참이라 보류 | [표준 261846](https://stdict.korean.go.kr/search/searchView.do?word_no=261846&searchKeywordTo=3) |
| 가락 | 가락1(물레 꼬챙이·국수 가락)이 먼저 읽히고, 헤드폰·악기만으로는 소리가 나는지 모름 | [표준 383279](https://stdict.korean.go.kr/search/searchView.do?word_no=383279&searchKeywordTo=3) |
| 시나브로 | 부사(앱 단어는 모두 명사) | [표준 452218](https://stdict.korean.go.kr/search/searchView.do?word_no=452218&searchKeywordTo=3) |
| 이야기꽃·얘기꽃·웃음꽃 | 이야기·웃음은 사진으로 모름 | [표준 265763](https://stdict.korean.go.kr/search/searchView.do?word_no=265763&searchKeywordTo=3), [468270](https://stdict.korean.go.kr/search/searchView.do?word_no=468270&searchKeywordTo=3) |
| 만남 | 「만나는 일」 — 사람 한 명 사진에도 붙음 | [표준 108602](https://stdict.korean.go.kr/search/searchView.do?word_no=108602&searchKeywordTo=3) |
| 말동무 | 말벗과 같은 뜻 | [표준 423105](https://stdict.korean.go.kr/search/searchView.do?word_no=423105&searchKeywordTo=3) |
| 한솥밥 | 「같은 솥에서 푼 밥」 — 식구·동료 관계를 말함 | [표준 365338](https://stdict.korean.go.kr/search/searchView.do?word_no=365338&searchKeywordTo=3) |
| 지난날 | 액자 속이 옛 사진인지 그림인지 모름 | [표준 484397](https://stdict.korean.go.kr/search/searchView.do?word_no=484397&searchKeywordTo=3) |
| 나들이 | 표(`ticket`)가 있어도 「가까운 곳에 잠시 다녀오는 일」은 모름 | [표준 405891](https://stdict.korean.go.kr/search/searchView.do?word_no=405891&searchKeywordTo=3) |
| 셈·씀씀이 | 영수증엔 맞지만 감성이 없고, 씀씀이는 평가가 들어감 | [표준 446050](https://stdict.korean.go.kr/search/searchView.do?word_no=446050&searchKeywordTo=3), [453702](https://stdict.korean.go.kr/search/searchView.do?word_no=453702&searchKeywordTo=3) |
| 볼거리 | 볼거리2(유행성 이하선염)와 같은 꼴 | [표준 148516](https://stdict.korean.go.kr/search/searchView.do?word_no=148516&searchKeywordTo=3) |
| 노리개 | 「1」 한복 장신구, 「3」 「장난삼아 데리고 노는 사람을 낮잡아 이르는 말」 | [표준 408281](https://stdict.korean.go.kr/search/searchView.do?word_no=408281&searchKeywordTo=3) |
| 소꿉 | 소꿉 그릇을 따로 잡는 라벨이 없음 | [표준 190286](https://stdict.korean.go.kr/search/searchView.do?word_no=190286&searchKeywordTo=3) |
| 조각 | 퍼즐 조각에 맞지만 조각5(彫刻)와 같은 꼴 | [표준 485015](https://stdict.korean.go.kr/search/searchView.do?word_no=485015&searchKeywordTo=3) |
| 주사위 | 물건 이름표 | [표준 298017](https://stdict.korean.go.kr/search/searchView.do?word_no=298017&searchKeywordTo=3) |
| 저녁결 | 「저녁때가 지나는 동안」 — 대상과 상관없는 때 말이라 앞선 조사 「저녁나절」 쪽 몫 | [표준 283606](https://stdict.korean.go.kr/search/searchView.do?word_no=283606&searchKeywordTo=3) |
| 틈 | 「1」 벌어져 사이가 난 자리가 먼저 읽힘 | [표준 498788](https://stdict.korean.go.kr/search/searchView.do?word_no=498788&searchKeywordTo=3) |
