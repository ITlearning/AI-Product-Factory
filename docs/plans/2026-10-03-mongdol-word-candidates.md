# 몽돌 「사진 한 단어」 순우리말 후보 조사

2026-10-03 · 조사만, 코드는 고치지 않음 · 대상: `Shared/Word/words.json`(v2, 54단어)

## 검증 방법
- 모든 후보는 **표준국어대사전**(stdict.korean.go.kr)에서 검색 결과와 상세 화면(`contentViewOne.do`)을 직접 내려받아 뜻풀이·원어(한자)·**어원란**까지 확인했다. 표준국어대사전에 없는 말만 **우리말샘**(opendict.korean.go.kr)에서 확인했다. 출처 칸의 「표준 번호」는 표준국어대사전 word_no 링크다.
- 고유어 판정: 표제어 원어란에 한자가 없고, **어원란에도 한자가 없을 때만** 통과. 원어란은 비었지만 어원란에 한자가 나오는 말(처마←檐牙, 썰매←雪馬, 천둥←天動, 접시←楪子)도 제외했다.
- 라벨 이름은 `vision-labels.txt`에 있는 것만 썼다(스크립트로 전수 대조, 조약돌 이름·지금 목록과 겹침도 같이 검사 — 통과).
- 「제안값」이라고 적은 기온 문턱은 근거가 없는 내 제안이다. 근거가 있는 문턱은 기상청 특보 기준 하나뿐이다: 폭염주의보 일 최고 체감 33°C, 폭염경보 35°C, 한파주의보 아침 최저 −12°C(또는 전날보다 10°C 이상 떨어져 3°C 이하), 한파경보 −15°C ([기상청 날씨누리 특보 발표기준](https://www.weather.go.kr/w/forecast/guide/standard.do)).
- ★ = 각 절에서 가장 추천하는 말.

## 0. 먼저: 정직하게 붙이려면 필요한 조건 (지금 `WordEntry`에 없는 것)
지금 단어 조건은 `times`(6칸)·`weathers`(7종)·`seasons`(4계절)·`subjects`(OR)뿐이다(`Shared/Word/WordList.swift`). 그런데 앱은 이미 더 많은 사실을 갖고 있다. `PlaceWeather`에 **WeatherKit 원본 condition 문자열과 섭씨 기온**이 저장되고(`Shared/Day/Moment.swift`), `PhotoContext`는 **찍은 시각 전체**를 받는다. 이 후보의 절반은 아래 조건이 있어야 거짓말을 안 한다.

| 필요한 조건 | 왜 | 쓰는 후보 |
|---|---|---|
| **라벨 AND**(`subjectsAll`) | 「눈 덮인 길」은 눈 **그리고** 길. 지금은 OR라 눈만 있어도, 길만 있어도 붙는다 | 남새밭·눈꽃·눈길, 지금의 길섶 |
| **달(month)** | 계절 3개월 안에서도 첫·한·늦이 갈린다 | 첫봄·한봄·늦봄·한가을·늦가을, 꽃샘·잎샘, 건들바람, 늦더위 |
| **시(hour)** 또는 **태양 고도** | 시간대 칸은 고정인데 해 뜨고 지는 시각은 계절마다 바뀐다. 서울 7/15 17:30은 해 높이 26°(「땅거미」=해 진 뒤가 거짓), 12/15 06:30은 −13°(아직 밤), 6/15 06:30은 +13°(「어둑새벽」이 거짓). 리포에 이미 `docs/designs/tools/sun-altitude-check.mjs`(외부 API 없는 태양 고도 계산)가 있다 | 꼭두새벽·첫새벽·어둑새벽·어슬녘·어둑발, 밤참, 지금의 한밤·땅거미·해거름·먼동 |
| **기온 범위** | 「더위」「추위」「찬비」는 기온이 사실이다. `celsius`는 저장돼 있는데 단어 쪽에 필드가 없다 | 불볕더위·강추위·찬비·칼바람·목도리, 지금의 꽃샘추위·한여름·한겨울 |
| **원본 condition** | 7종 날씨로 뭉개면 `heavyRain`과 이슬비 같은 `rain`이, `flurries`와 `heavySnow`가 같아진다(`DayPhotoView.swift:57-72`) | 작달비·억수(`heavyRain`), 가랑눈(`flurries`), 눈보라(`blowingSnow`), 우레(뇌우), 지금의 여우비(`sunShowers`)·진눈깨비(`sleet`·`wintryMix`) |
| **월령**(날짜로 계산) | 달 모양은 날짜만으로 계산된다 | 조각달·눈썹달, 지금의 달맞이(음력 1/15·8/15) |
| **계절을 풀지 않는 표시** | C-0 참고. 계절이 뜻의 일부인 말은 계절이 안 맞으면 버려야 한다 | 봄꽃, 꽃샘추위, 하늬바람·된바람, 진눈깨비 |
| (보류) 풍향·습도·강수량 | 저장 안 됨. 없으면 아래 후보는 못 쓴다 | 마파람·샛바람·높새바람·하늬바람(풍향), 무더위(습도) |

## A. 대상 단어 (사진에 찍힌 것)
`outdoor`·`structure`·`machine`·`furniture`·`adult`만으로 붙는 말은 넣지 않았다. 앞의 다섯은 Tabber 사진 56장에서 28·28·9·6·9번 나와 근거가 못 된다.

| 단어 | 사전 뜻풀이(요약) | 앱용 한 줄 뜻 | 붙일 라벨 | 시간대·달·날씨·기온 조건 | 주장하는 사실 → 확인 수단 | 출처 | 비고 |
|---|---|---|---|---|---|---|---|
| **★풀꽃** | 풀에 피는 꽃 | 풀에 피는 꽃 | `daisy`·`dandelion`·`daffodil`·`tulip`·`cornflower`·`marigold`·`petunia`·`snapdragon`·`begonia`·`carnation`·`chrysanthemum`·`dahlia`·`clover`·`lily`·`orchid`·`sunflower` | 없음 | 풀(초본)에 핀 꽃 → 초본 꽃 종 라벨 | [표준 356780](https://stdict.korean.go.kr/search/searchView.do?word_no=356780&searchKeywordTo=3) | `flower`·`blossom`·`rose` 단독은 나무꽃일 수 있어 뺌. 「들꽃」은 「들에 핀」이라 꽃병 꽃에 거짓 → 풀꽃으로. Tabber 사진 `daffodil` 1장 |
| **봄꽃** | 봄에 피는 꽃 | 봄에 피는 꽃 | `flower`·`blossom`·`daffodil`·`tulip`·`dandelion`·`daisy` | 3–5월. **계절 완화 금지** | 봄에 핀 꽃 → 꽃 라벨 + 찍은 달 | [표준 434698](https://stdict.korean.go.kr/search/searchView.do?word_no=434698&searchKeywordTo=3) | 지금 `candidates`는 계절을 2단계에서 풀어 버려 가을 꽃에도 붙는다(C-0 참고) |
| **꽃송이** | 꽃자루 위의 꽃 전체 | 꽃자루 위에 달린 꽃 한 덩이 | `flower`·`blossom`·`rose`·풀꽃 라벨 전부 | 없음 | 꽃이 찍혔다 → 꽃 라벨 | [표준 404193](https://stdict.korean.go.kr/search/searchView.do?word_no=404193&searchKeywordTo=3) | 가장 안전한 꽃 말. 「꽃망울」은 봉오리인지 판별 불가라 뺌 |
| **꽃나무** | 꽃이 피는 나무 | 꽃이 피는 나무 | `blossom` (+ `tree` 있으면 더 확실) | 없음 | 나무에 핀 꽃 → `blossom` | [표준 55249](https://stdict.korean.go.kr/search/searchView.do?word_no=55249&searchKeywordTo=3) | `blossom`이 나무꽃만 뜻하는지는 Apple이 정의를 공개하지 않음 — 요확인 |
| **꽃다발** | 꽃으로 만든 다발 | 꽃을 모아 묶은 다발 | `bouquet` | 없음 | 꽃다발 → `bouquet` | [표준 404552](https://stdict.korean.go.kr/search/searchView.do?word_no=404552&searchKeywordTo=3) |  |
| **꽃꽂이** | 꽃이나 나뭇가지를 꽃병·수반에 꽂아 꾸미는 일 | 꽃이나 나뭇가지를 꽃병에 꽂아 꾸미는 일 | `flower_arrangement` | 없음 | 꽃병에 꽂은 꽃 → `flower_arrangement` | [표준 404566](https://stdict.korean.go.kr/search/searchView.do?word_no=404566&searchKeywordTo=3) |  |
| **★늘푸른나무** | 사철 내내 잎이 푸른 나무(=상록수) | 사철 내내 잎이 푸른 나무 | `evergreen`·`sequoia`·`palm_tree` | 없음 | 상록수 → 수종 라벨 | [표준 71394](https://stdict.korean.go.kr/search/searchView.do?word_no=71394&searchKeywordTo=3) | `christmas_tree`는 인조일 수 있어 뺌 |
| **떨기나무** | 키가 작고 밑동에서 가지를 많이 치는 나무(=관목) | 밑동에서 가지를 많이 치는 키 작은 나무 | `shrub` | 없음 | 관목 → `shrub` | [표준 98364](https://stdict.korean.go.kr/search/searchView.do?word_no=98364&searchKeywordTo=3) | 지금 「길섶」이 `shrub`을 쓰지만 길이 없어도 붙음(C 참고) |
| **★푸나무** | 풀과 나무를 아울러 이르는 말 | 풀과 나무를 아울러 이르는 말 | `plant`·`decorative_plant`·`vegetation` | 없음 | 풀이나 나무가 있다 → 식물 라벨 | [표준 357880](https://stdict.korean.go.kr/search/searchView.do?word_no=357880&searchKeywordTo=3) | Tabber 사진 `plant` 7장 담당. 동형어 「푸나무2」(=풋나무)는 땔나무 뜻이니 뜻풀이로 구분 |
| **덩굴** | 길게 뻗어 다른 물건을 감거나 땅에 퍼지는 식물 줄기 | 길게 뻗어 감고 오르는 식물 줄기 | `ivy` | 없음 | 덩굴식물 → `ivy` | [표준 84298](https://stdict.korean.go.kr/search/searchView.do?word_no=84298&searchKeywordTo=3) | 「담쟁이」도 순우리말이지만 사전 뜻이 특정 종(포도과)이라 Vision `ivy`(송악 포함)와 어긋날 수 있음 |
| **버들** | 버드나무속 식물(=버드나무) | 버드나무 | `willow` | 없음 | 버드나무 → `willow` | [표준 142723](https://stdict.korean.go.kr/search/searchView.do?word_no=142723&searchKeywordTo=3) |  |
| **푸성귀** | 사람이 가꾼 채소나 저절로 난 나물을 통틀어 이르는 말 | 가꾼 채소와 저절로 난 나물을 아우르는 말 | `vegetable`·`lettuce`·`spinach`·`broccoli`·`cauliflower`·`cucumber`·`carrot`·`radish`·`daikon`·`celery`·`leek`·`zucchini`·`eggplant`·`kohlrabi`·`arugula` | 없음 | 채소·나물 → 채소 라벨 | [표준 503417](https://stdict.korean.go.kr/search/searchView.do?word_no=503417&searchKeywordTo=3) | Tabber 사진 `vegetable` 1장 |
| **남새밭** | 채소를 심어 가꾸는 밭 | 채소를 심어 가꾸는 밭 | `vegetable` **그리고** `garden`·`farm`·`agriculture` | 없음 | 채소가 자라는 밭 → 채소 라벨과 밭 라벨이 **둘 다** | [표준 61569](https://stdict.korean.go.kr/search/searchView.do?word_no=61569&searchKeywordTo=3) | 라벨 AND 매칭 필요(지금은 OR). 「텃밭」은 「집 가까이」라 뺌 |
| **뜨락** | 집 안의 앞뒤나 좌우로 딸려 있는 빈터(=뜰) | 집에 딸린 앞뒤 빈터 | `garden`·`patio` | 없음 | 집에 딸린 마당 → `garden` | [표준 99075](https://stdict.korean.go.kr/search/searchView.do?word_no=99075&searchKeywordTo=3) | 공원 정원에도 `garden`이 붙을 수 있어 약간 넓음. 「뜰」도 같은 뜻 |
| **★둔덕** | 가운데가 솟아 불룩하게 언덕이 진 곳 | 가운데가 불룩하게 솟은 언덕 | `hill` | 없음 | 언덕 → `hill` | [표준 418151](https://stdict.korean.go.kr/search/searchView.do?word_no=418151&searchKeywordTo=3) | Tabber 사진 `hill` 2장. 대안 「비탈」(161036, 기울어진 곳) |
| **벼랑** | 낭떠러지의 험하고 가파른 언덕 | 험하고 가파른 낭떠러지 | `cliff`·`canyon` | 없음 | 가파른 절벽 → `cliff` | [표준 432488](https://stdict.korean.go.kr/search/searchView.do?word_no=432488&searchKeywordTo=3) |  |
| **★바윗돌** | 바위를 돌로 이르는 말. 또는 바위처럼 큰 돌 | 바위처럼 큰 돌 | `rocks`·`megalith` | 없음 | 큰 돌 → `rocks` | [표준 130161](https://stdict.korean.go.kr/search/searchView.do?word_no=130161&searchKeywordTo=3) | Tabber 사진 `rocks` 5장. 「몽돌」은 앱 이름이라 제외 |
| **개울** | 골짜기나 들에 흐르는 작은 물줄기 | 골짜기나 들을 흐르는 작은 물줄기 | `creek` | 없음 | 작은 물줄기 → `creek` | [표준 11120](https://stdict.korean.go.kr/search/searchView.do?word_no=11120&searchKeywordTo=3) | 대안 「냇가」(63693, 냇물의 가장자리) — `creek`·`river` |
| **늪** | 늘 물이 괴어 있고 진흙 바닥에 물풀이 자라는 곳 | 물이 늘 괴어 있는 진흙 땅 | `wetland` | 없음 | 습지 → `wetland` | [표준 410714](https://stdict.korean.go.kr/search/searchView.do?word_no=410714&searchKeywordTo=3) |  |
| **돛단배** | 돛을 단 배 | 돛을 단 배 | `sailboat` | 없음 | 돛 → `sailboat` | [표준 92092](https://stdict.korean.go.kr/search/searchView.do?word_no=92092&searchKeywordTo=3) |  |
| **거룻배** | 돛이 없는 작은 배 | 돛 없는 작은 배 | `rowboat`·`canoe`·`kayak` | 없음 | 돛 없는 작은 배 → 노 젓는 배 라벨 | [표준 11230](https://stdict.korean.go.kr/search/searchView.do?word_no=11230&searchKeywordTo=3) | 「쪽배」는 「통나무를 파서 만든」이라 카누·카약에 거짓 |
| **건널목** | 「2」 강·길·내 따위에서 건너다니게 된 일정한 곳 | 길을 건너다니게 된 곳 | `crosswalk` | 없음 | 횡단보도 → `crosswalk` | [표준 391730](https://stdict.korean.go.kr/search/searchView.do?word_no=391730&searchKeywordTo=3) | 「1」은 철도 건널목. 뜻풀이로 「2」를 씀 |
| **밤거리** | 밤의 거리 | 밤의 거리 | `street`·`alley`·`sidewalk`·`cityscape` | 밤(20–03:59) | 밤에 찍은 거리 → 라벨 + 시각 | [우리말샘](https://opendict.korean.go.kr/search/searchResult?query=%EB%B0%A4%EA%B1%B0%EB%A6%AC) | 우리말샘만 등재(표준국어대사전 없음). 「2」 범죄 세계 비유도 있음 — 앱 뜻풀이로 「1」 고정 |
| **가게** | 작은 규모로 물건을 파는 집 | 작은 규모로 물건을 파는 집 | `storefront`·`interior_shop` | 없음 | 가게 → 가게 라벨 | [표준 386696](https://stdict.korean.go.kr/search/searchView.do?word_no=386696&searchKeywordTo=3) | 사전 어원란 「가개」 — 한자 표시 없음 |
| **술집** | 술을 파는 집 | 술을 파는 집 | `bar`·`nightclub` | 없음 | 술집 → `bar` | [표준 446318](https://stdict.korean.go.kr/search/searchView.do?word_no=446318&searchKeywordTo=3) | 「밥집」은 「싼값에 파는 집」이라 레스토랑에 거짓 → 제외 |
| **부엌** | 음식을 만들고 설거지를 하는 곳 | 음식을 만들고 치우는 곳 | `kitchen`·`kitchen_room`·`kitchen_countertop`·`kitchen_sink`·`kitchen_oven`·`stove` | 없음 | 부엌 → 부엌 라벨 | [표준 159783](https://stdict.korean.go.kr/search/searchView.do?word_no=159783&searchKeywordTo=3) |  |
| **★밥때** | 밥을 먹을 때 | 밥을 먹을 때 | `food`·`tableware`·`utensil`·`plate`·`bowl`·`chopsticks`·`rice` | 아침·낮·저녁(07–14:59, 17–19:59). 새벽·오후·밤 제외 | 끼니 시각이다 → **시각**(행동이 아니라 때를 말함) | [표준 517446](https://stdict.korean.go.kr/search/searchView.do?word_no=517446&searchKeywordTo=3) | Tabber `tableware` 10·`utensil` 11·`plate` 4·`bowl` 2장 담당. 빈 그릇만 찍혀도 「때」는 참 |
| **밤참** | 저녁밥을 먹고 한참 뒤 밤중에 먹는 음식 | 저녁을 먹고 한참 뒤 밤중에 먹는 음식 | `food`·`ramen`·`fried_chicken`·`pizza`·`hamburger`·`tableware` | 밤. 단 **21–02시** 권장(20시는 저녁밥 시간) | 밤늦게 먹는 음식 → 음식 라벨 + 시각 | [표준 140829](https://stdict.korean.go.kr/search/searchView.do?word_no=140829&searchKeywordTo=3) | 시간대 「밤」(20–03:59)만으로는 20시 저녁밥에도 붙음 → 시(hour) 조건 필요 |
| **★술자리** | 술을 마시며 노는 자리. 또는 술상을 베푼 자리 | 술을 마시며 노는 자리 | `beer`·`wine`·`red_wine`·`white_wine`·`sparkling_wine`·`cocktail`·`liquor`·`sangria`·`margarita`·`martini`·`mojito`·`tequila` | 없음(저녁·밤 권장) | 술이 있다 → 술 라벨 | [표준 193102](https://stdict.korean.go.kr/search/searchView.do?word_no=193102&searchKeywordTo=3) | Tabber `liquid` 5·`drinking_glass` 5장 중 술잔인 것 담당 |
| **차림새** | 차린 그 모양(차림 = 옷 따위를 입어 갖춘 상태) | 옷 따위를 차려 갖춘 모양새 | `clothing`·`jacket`·`jeans`·`suit`·`hoodie`·`footwear` | 없음 | 옷차림이 찍혔다 → 옷 라벨 | [표준 319702](https://stdict.korean.go.kr/search/searchView.do?word_no=319702&searchKeywordTo=3) | 「옷맵시」(459711)는 「어울리는」이라는 평가가 들어가 확인 불가 |
| **목도리** | 추위를 막기 위하여 목에 두르는 물건 | 추위를 막으려 목에 두르는 것 | `scarf` | 기온 ≤ 12°C(제안값) | 추위 막이 → `scarf` + 기온 | [표준 117269](https://stdict.korean.go.kr/search/searchView.do?word_no=117269&searchKeywordTo=3) | 여름 패션 스카프엔 「추위」가 거짓 → 기온 조건 |
| **빨랫줄** | 빨래를 널어 말리려고 다는 줄 | 빨래를 널어 말리는 줄 | `clothesline`·`clothespin` | 없음 | 빨랫줄 → `clothesline` | [표준 166251](https://stdict.korean.go.kr/search/searchView.do?word_no=166251&searchKeywordTo=3) |  |
| **털실** | 짐승 털이나 인조털로 만든 실 | 털로 만든 실 | `yarn` | 없음 | 털실 → `yarn` | [표준 348693](https://stdict.korean.go.kr/search/searchView.do?word_no=348693&searchKeywordTo=3) | 대안 「실타래」(452380) |
| **바느질** | 바늘에 실을 꿰어 옷 따위를 짓거나 꿰매는 일 | 바늘과 실로 짓거나 꿰매는 일 | `sewing` | 없음 | 바느질 → `sewing` | [표준 129908](https://stdict.korean.go.kr/search/searchView.do?word_no=129908&searchKeywordTo=3) |  |
| **꼬마** | 어린아이를 귀엽게 이르는 말 | 어린아이를 귀엽게 이르는 말 | `child` | 없음 | 어린아이 → `child` | [표준 403852](https://stdict.korean.go.kr/search/searchView.do?word_no=403852&searchKeywordTo=3) | Tabber `child` 1장. `teen`엔 붙이지 않음 |
| **아기** | 어린 젖먹이 아이 | 어린 젖먹이 아이 | `baby` | 없음 | 젖먹이 → `baby` | [표준 455020](https://stdict.korean.go.kr/search/searchView.do?word_no=455020&searchKeywordTo=3) |  |
| **놀이터** | 주로 아이들이 놀이를 하는 곳 | 아이들이 노는 곳 | `playground`·`swing_playground`·`slide_toy`·`seesaw` | 없음 | 놀이터 → 놀이기구 라벨 | [표준 408844](https://stdict.korean.go.kr/search/searchView.do?word_no=408844&searchKeywordTo=3) | 「그네」(401617)·「미끄럼틀」(128390)도 순우리말 확인 |
| **장난감** | 아이들이 가지고 노는 여러 가지 물건 | 아이들이 가지고 노는 물건 | `toy`·`stuffed_animals`·`doll`·`vehicle_toy`·`train_toy`·`blocks` | 없음 | 장난감 → 장난감 라벨 | [표준 276244](https://stdict.korean.go.kr/search/searchView.do?word_no=276244&searchKeywordTo=3) |  |
| **★털북숭이** | 털이 많이 난 것 | 털이 많이 난 것 | `cat`·`kitten`·`adult_cat`·`feline`·`pomeranian`·`poodle`·`bichon`·`malamute`·`husky`·`newfoundland`·`saint_bernard`·`collie`·`sheepdog`·`bernese_mountain`·`australian_shepherd`·`chinchilla` | 없음 | 털이 많다 → 털 많은 종 라벨만 | [표준 347519](https://stdict.korean.go.kr/search/searchView.do?word_no=347519&searchKeywordTo=3) | Tabber `animal`·`feline` 1장. `dog` 단독은 치와와·닥스훈트에 거짓이라 뺌. 「강아지」는 「개의 새끼」라 다 큰 개에 거짓 |
| **둥지** | 새가 알을 낳거나 깃들이는 곳 | 새가 알을 낳고 깃드는 곳 | `nest`·`birdhouse` | 없음 | 둥지 → `nest` | [표준 414741](https://stdict.korean.go.kr/search/searchView.do?word_no=414741&searchKeywordTo=3) | 지금 「보금자리」 뜻 「1」도 같은 뜻 — `nest`를 보금자리에 더해도 됨 |
| **거미줄** | 거미가 뽑아낸 줄. 또는 그 줄로 된 그물 | 거미가 뽑아 친 줄 | `spiderweb` | 없음 | 거미줄 → `spiderweb` | [표준 392634](https://stdict.korean.go.kr/search/searchView.do?word_no=392634&searchKeywordTo=3) |  |
| **★달밤** | 달이 떠서 밝은 밤 | 달이 떠서 밝은 밤 | `moon` | 저녁·밤 | 달이 떴다 → `moon` + 시각 | [표준 77432](https://stdict.korean.go.kr/search/searchView.do?word_no=77432&searchKeywordTo=3) | 「달맞이」 대체(C 참고) |
| **★조각달** | 음력 5일 전후·25일 전후에 뜨는, 반달보다 더 이지러진 달 | 반달보다 더 이지러진 달 | `moon` | 월령 3–7일 또는 23–27일(계산) | 달 모양 → `moon` + **날짜로 계산한 월령** | [표준 303568](https://stdict.korean.go.kr/search/searchView.do?word_no=303568&searchKeywordTo=3) | 월령은 날짜만으로 계산 가능 — 새 조건 필드 필요 |
| **눈썹달** | 눈썹 모양으로 보이는 초승달이나 그믐달 | 눈썹처럼 가는 초승달이나 그믐달 | `moon` | 월령 ≤ 3일 또는 ≥ 27일(계산) | 가는 달 → `moon` + 월령 | [표준 70488](https://stdict.korean.go.kr/search/searchView.do?word_no=70488&searchKeywordTo=3) |  |
| **★아침노을** | 아침 하늘이 햇살로 벌겋게 보이는 현상(준말 아침놀) | 아침 하늘이 햇살로 벌겋게 물드는 것 | `sunset_sunrise` | 새벽·아침 | 아침 하늘이 붉다 → `sunset_sunrise` + 시각 | [표준 211827](https://stdict.korean.go.kr/search/searchView.do?word_no=211827&searchKeywordTo=3) | 「노을」「저녁놀」은 조약돌 이름이지만 아침노을·아침놀(212359)은 안 겹침 |
| **★눈꽃** | 나뭇가지 따위에 꽃이 핀 것처럼 얹힌 눈 | 나뭇가지에 꽃처럼 얹힌 눈 | `snow` **그리고** `tree`·`evergreen`·`branch` | 없음 | 나무에 눈이 얹혔다 → 눈 + 나무 라벨 **둘 다** | [표준 409664](https://stdict.korean.go.kr/search/searchView.do?word_no=409664&searchKeywordTo=3) | AND 매칭 필요 |
| **눈밭** | 눈이 덮인 땅 | 눈이 덮인 땅 | `snow`·`snowman`·`sledding` | 없음 | 눈 덮인 땅 → `snow` | [표준 410271](https://stdict.korean.go.kr/search/searchView.do?word_no=410271&searchKeywordTo=3) | 내리는 눈이 아니라 쌓인 눈을 말하므로 날씨와 무관해 안전 |
| **눈길** | 「2」 눈에 덮인 길 | 눈에 덮인 길 | `snow` **그리고** `road`·`path`·`street`·`sidewalk`·`trail` | 없음 | 눈 덮인 길 → 눈 + 길 라벨 **둘 다** | [표준 72036](https://stdict.korean.go.kr/search/searchView.do?word_no=72036&searchKeywordTo=3) | 동형어 「눈길1」(시선) — 뜻풀이로 구분 |
| **얼음판** | 물이 얼어서 마당처럼 된 곳 | 물이 얼어 마당처럼 된 곳 | `rink`·`ice_skating` | 없음 | 언 바닥 → 링크 라벨 | [표준 227316](https://stdict.korean.go.kr/search/searchView.do?word_no=227316&searchKeywordTo=3) | `ice`는 음료 얼음에도 붙어 뺌. 「썰매」는 어원 雪馬라 제외 |
| **헤엄** | 사람이나 물고기가 물속에서 나아가려 팔다리·지느러미를 움직이는 일 | 물속에서 팔다리를 놀려 나아가는 일 | `swimming` | 없음 | 헤엄 → `swimming` | [표준 501064](https://stdict.korean.go.kr/search/searchView.do?word_no=501064&searchKeywordTo=3) | 대안 「자맥질」(473521, 떴다 잠겼다) — `snorkeling` |
| **모래밭** | 모래가 넓게 덮여 있는 곳 | 모래가 넓게 덮인 곳 | `sand`·`sand_dune`·`beach` | 없음 | 모래땅 → 모래 라벨 | [표준 117186](https://stdict.korean.go.kr/search/searchView.do?word_no=117186&searchKeywordTo=3) | 「모래톱」은 조약돌 이름 |
| **번개** | 구름 사이·구름과 땅 사이 방전으로 번쩍이는 불꽃 | 구름에서 번쩍이는 불꽃 | `lightning` | 없음 | 번개가 찍혔다 → `lightning` | [표준 431506](https://stdict.korean.go.kr/search/searchView.do?word_no=431506&searchKeywordTo=3) | 「천둥」은 어원 天動이라 제외 → B의 「우레」 |

### A 보조: 정직하지만 밋밋한 말 (자리가 비면)
- **그릇**([표준 400597](https://stdict.korean.go.kr/search/searchView.do?word_no=400597&searchKeywordTo=3), 음식이나 물건을 담는 기구) — `tableware`·`bowl`·`plate`. 식기 쪽 고운 순우리말은 거의 다 한자가 섞였다(밥상 床, 사발 沙鉢, 접시 楪子, 항아리 缸). 그래서 A에서는 「밥때」처럼 **그릇이 아니라 때를 말하는 말**로 우회했다.
- **탈것**([표준 493597](https://stdict.korean.go.kr/search/searchView.do?word_no=493597&searchKeywordTo=3), 자전거·자동차 따위 사람이 타고 다니는 물건) — `automobile`·`car`·`vehicle`·`bicycle`.
- **지붕**([표준 484100](https://stdict.korean.go.kr/search/searchView.do?word_no=484100&searchKeywordTo=3), 어원 집+웋) — `roof`.
- **불빛**(지금 목록) — 뜻 「2」 「켜 놓은 불에서 비치는 빛」([표준 440349](https://stdict.korean.go.kr/search/searchView.do?word_no=440349&searchKeywordTo=3)). `cityscape`·`skyscraper`·`building`을 저녁·밤 조건으로 더하면 건물·도시 사진(Tabber 최대 13장)을 정직하게 받는다. 밤 도시에는 반드시 불이 켜져 있다.

### Tabber 사진의 어휘 밖 라벨 → 이번 후보
| 라벨(장) | 받는 후보 | 비고 |
|---|---|---|
| `utensil`(11)·`tableware`(10)·`plate`(4)·`bowl`(2) | 밥때·밤참·그릇 | 고운 식기 이름은 한자 섞임 |
| `plant`(7) | 푸나무 | |
| `building`(7)·`skyscraper`(4)·`cityscape`(2) | 불빛(저녁·밤)·밤거리·가게·지붕 | 낮의 고층 건물에 맞는 고운 고유어는 찾지 못함(마천루·빌딩은 한자·외래어) |
| `liquid`(5)·`drinking_glass`(5)·`bottle`(2) | 술자리(술일 때) | 물잔·병은 한자(盞·甁) |
| `rocks`(5) | 바윗돌 | |
| `hill`(2) | 둔덕 (또는 비탈) | |
| `clothing`(2) | 차림새 | |
| `art`(2)·`illustrations` | 그림(밋밋) | 손글씨는 우리말샘에 「손 글씨」 두 단어로만 있음 |
| `automobile`·`vehicle`·`car`(2) | 탈것(밋밋) | |
| `vegetable` | 푸성귀·남새밭 | |
| `child` | 꼬마 | |
| `animal`·`feline` | 털북숭이 | |
| `daffodil` | 풀꽃·봄꽃 | 수선화는 한자 |
| `fence` | 보류 | 「울타리」 뜻이 「풀이나 나무를 엮어」라 쇠 울타리에 거짓 |
| `christmas_tree`·`curtain`·`eyeglasses`·`consumer_electronics`·`container` | 없음 | 정직한 순우리말을 찾지 못함 |

## B. 때 단어 (대상과 상관없이 그 순간만)
지금 있는 말(먼동·아침나절·한낮·한나절·해거름·땅거미·한밤·는개·가랑비·보슬비·소나기·함박눈·진눈깨비·하늬바람·된바람·한여름·한겨울·찬바람머리)과 조약돌 이름은 피했다.

### B-1. 시간대
| 단어 | 사전 뜻풀이(요약) | 앱용 한 줄 뜻 | 붙일 라벨 | 시간대·달·날씨·기온 조건 | 주장하는 사실 → 확인 수단 | 출처 | 비고 |
|---|---|---|---|---|---|---|---|
| **꼭두새벽** | 아주 이른 새벽 | 아주 이른 새벽 | — | 새벽 중 **04:00–04:59** | 아주 이른 시각 → 시(hour) | [표준 404377](https://stdict.korean.go.kr/search/searchView.do?word_no=404377&searchKeywordTo=3) | 새벽녘·갓밝이·새벽빛은 조약돌 이름 |
| **첫새벽** | 날이 새기 시작하는 새벽 | 날이 새기 시작하는 새벽 | — | 새벽 + **해 뜨기 전 1시간 안**(태양 고도 −12°~0°) | 날이 새기 시작 → 일출 시각 계산 | [표준 487506](https://stdict.korean.go.kr/search/searchView.do?word_no=487506&searchKeywordTo=3) | 「신새벽」은 사전이 비표준어로 둠 |
| **어둑새벽** | 날이 밝기 전 어둑어둑한 새벽 | 날이 밝기 전 어둑한 새벽 | — | 새벽 + **태양 고도 < −6°** | 아직 어둡다 → 태양 고도 | [표준 227681](https://stdict.korean.go.kr/search/searchView.do?word_no=227681&searchKeywordTo=3) | 6월 06시엔 이미 환함 → 시간대만으로는 거짓 |
| **아침결** | 아침때가 지나는 동안 | 아침때가 지나는 동안 | — | 아침(07–10:59). 07–09시 권장 | 아침 시각 → 시각 | [표준 211823](https://stdict.korean.go.kr/search/searchView.do?word_no=211823&searchKeywordTo=3) | 「아침참」은 「아침밥 먹고 쉬는 동안」이라 행동 주장 → 제외 |
| **★낮때** | 한낮을 중심으로 한 한동안 | 한낮을 중심으로 한 한동안 | — | 낮(11–14:59) | 정오 무렵 → 시각 | [표준 63371](https://stdict.korean.go.kr/search/searchView.do?word_no=63371&searchKeywordTo=3) |  |
| **대낮** | 환히 밝은 낮 | 환히 밝은 낮 | — | 낮 + 맑음(`clear`·`mostlyClear`·`partlyCloudy`) | 환하다 → 시각 + 맑음 | [표준 413906](https://stdict.korean.go.kr/search/searchView.do?word_no=413906&searchKeywordTo=3) | 비 오는 낮엔 「환히」가 어긋나 맑음 조건 |
| **낮곁** | 한낮부터 해 질 때까지를 둘로 나눈 앞 절반 | 한낮이 기운 뒤 오후 한때 | — | 12:00–15:59 (낮 후반·오후 전반) | 오후 앞 절반 → 시각 | [표준 61437](https://stdict.korean.go.kr/search/searchView.do?word_no=61437&searchKeywordTo=3) | 오후(15–16:59) 칸을 따로 부르는 순우리말은 사실상 없음 — 이 칸은 볕·바람·기온 말로 채우길 권함 |
| **★저녁나절** | 저녁때를 전후한 어느 무렵이나 동안 | 저녁때 앞뒤의 한동안 | — | 저녁(17–19:59) | 저녁 시각 → 시각 | [표준 283608](https://stdict.korean.go.kr/search/searchView.do?word_no=283608&searchKeywordTo=3) |  |
| **어둑발** | 사물을 뚜렷이 분간할 수 없을 만큼 어두운 빛살 | 사물을 분간하기 어려울 만큼 어두운 빛 | — | 저녁 + **해 진 뒤**(태양 고도 < 0°) | 어두워짐 → 일몰 계산 | [표준 460340](https://stdict.korean.go.kr/search/searchView.do?word_no=460340&searchKeywordTo=3) |  |
| **★어슬녘** | 날이 어두워지거나 밝아질 무렵 | 날이 어둑해지거나 밝아 올 무렵 | — | 새벽·저녁 + **태양 고도 −6°~+3°** | 박명 → 태양 고도 | [표준 227801](https://stdict.korean.go.kr/search/searchView.do?word_no=227801&searchKeywordTo=3) | 새벽·저녁 두 칸에 다 쓸 수 있음 |
| **★봄밤** | 봄철의 밤 | 봄철의 밤 | — | 밤 + 3–5월 | 봄 밤 → 시각 + 달 | [표준 149330](https://stdict.korean.go.kr/search/searchView.do?word_no=149330&searchKeywordTo=3) | 여름밤(459129)·가을밤(3019)·겨울밤(15616, 「겨울날의 긴 밤」)도 같은 방식 |
| **가을밤** | 가을철의 밤 | 가을철의 밤 | — | 밤 + 9–11월 | 가을 밤 → 시각 + 달 | [표준 3019](https://stdict.korean.go.kr/search/searchView.do?word_no=3019&searchKeywordTo=3) |  |

### B-2. 날씨
| 단어 | 사전 뜻풀이(요약) | 앱용 한 줄 뜻 | 붙일 라벨 | 시간대·달·날씨·기온 조건 | 주장하는 사실 → 확인 수단 | 출처 | 비고 |
|---|---|---|---|---|---|---|---|
| **★봄볕** | 봄철에 내리쬐는 햇볕 | 봄철에 내리쬐는 햇볕 | — | 맑음 + 아침·낮·오후 + 3–5월 | 볕이 난다 → 맑음 + 낮 + 달 | [표준 149338](https://stdict.korean.go.kr/search/searchView.do?word_no=149338&searchKeywordTo=3) | 가을볕(3022)·겨울볕(535507)·여름볕(535510)도 같은 방식. 오후(15–16:59) 칸 담당 |
| **★가을볕** | 가을철에 내리쬐는 햇볕 | 가을철에 내리쬐는 햇볕 | — | 맑음 + 아침·낮·오후 + 9–11월 | 볕 → 맑음 + 낮 + 달 | [표준 3022](https://stdict.korean.go.kr/search/searchView.do?word_no=3022&searchKeywordTo=3) |  |
| **볕살** | 햇볕의 따뜻한 기운 | 햇볕의 따뜻한 기운 | — | 맑음 + 아침·낮·오후 + 기온 10–25°C(제안값) | 볕이 따뜻하다 → 맑음 + 기온 | [표준 436275](https://stdict.korean.go.kr/search/searchView.do?word_no=436275&searchKeywordTo=3) | 「햇살」「햇볕」은 조약돌 이름이지만 볕살은 안 겹침 |
| **비구름** | 비나 눈을 내리게 하는 구름(=난운) | 비나 눈을 내리는 구름 | `cloudy`·`sky` | 비·이슬비·눈(실제 날씨) | 비를 내리는 구름 → 비 날씨 + 구름 라벨 | [표준 439462](https://stdict.korean.go.kr/search/searchView.do?word_no=439462&searchKeywordTo=3) | 「흐림」 날씨만으로 붙일 정직한 순우리말 명사는 찾지 못함(아래 참고) |
| **찬비** | 차갑게 느껴지는 비 | 차갑게 느껴지는 비 | — | 비·이슬비 + 기온 ≤ 10°C(제안값) | 비가 차다 → 비 + 기온 | [표준 318061](https://stdict.korean.go.kr/search/searchView.do?word_no=318061&searchKeywordTo=3) |  |
| **★밤비** | 밤에 내리는 비 | 밤에 내리는 비 | — | 비·이슬비 + 밤 | 밤에 오는 비 → 날씨 + 시각 | [표준 429545](https://stdict.korean.go.kr/search/searchView.do?word_no=429545&searchKeywordTo=3) |  |
| **봄비** | 봄철에 오는 비. 특히 조용히 가늘게 오는 비 | 봄철에 조용히 가늘게 오는 비 | — | 이슬비(또는 비) + 3–5월 | 봄 비 → 날씨 + 달 | [표준 154818](https://stdict.korean.go.kr/search/searchView.do?word_no=154818&searchKeywordTo=3) | 가을비(448)·겨울비(393184)도 같은 방식 |
| **★작달비** | 빗줄기가 굵고 거세게 좍좍 내리는 비(=장대비) | 굵고 거세게 좍좍 내리는 비 | — | 원본 condition `heavyRain`만 | 거센 비 → WeatherKit `heavyRain` | [표준 282982](https://stdict.korean.go.kr/search/searchView.do?word_no=282982&searchKeywordTo=3) | 「장대비」는 長대비라 제외. 「억수」(223763)도 같은 조건 |
| **빗소리** | 비가 내리는 소리 | 비가 내리는 소리 | — | 비(`rain`·`heavyRain`·뇌우 포함) | 비가 온다 → 날씨 | [표준 437382](https://stdict.korean.go.kr/search/searchView.do?word_no=437382&searchKeywordTo=3) |  |
| **우레** | 벼락·번개가 칠 때 대기가 요란하게 울림(=천둥) | 번개 칠 때 하늘이 요란하게 울리는 것 | `lightning`·`thunderstorm`·`storm` | 원본 condition `thunderstorms`·`isolatedThunderstorms`·`scatteredThunderstorms`·`strongStorms` | 뇌우 → condition | [표준 465021](https://stdict.korean.go.kr/search/searchView.do?word_no=465021&searchKeywordTo=3) | 어원 「울에←우르-」로 순우리말. 「우뢰」는 비표준어 |
| **실비** | 실같이 가늘게 내리는 비 | 실처럼 가늘게 내리는 비 | — | 이슬비 | 가는 비 → `drizzle` | [표준 449105](https://stdict.korean.go.kr/search/searchView.do?word_no=449105&searchKeywordTo=3) | 동형어 실비2(實費) |
| **안개비** | 빗줄기가 매우 가늘어 안개처럼 부옇게 보이는 비 | 안개처럼 부옇게 보이는 가는 비 | — | 이슬비(·안개) | 아주 가는 비 → `drizzle` | [표준 216551](https://stdict.korean.go.kr/search/searchView.do?word_no=216551&searchKeywordTo=3) |  |
| **먼지잼** | 비가 겨우 먼지나 날리지 않을 정도로 조금 옴 | 먼지나 겨우 재울 만큼 조금 오는 비 | — | 이슬비 | 아주 조금 오는 비 → `drizzle` | [표준 115758](https://stdict.korean.go.kr/search/searchView.do?word_no=115758&searchKeywordTo=3) |  |
| **★가랑눈** | 조금씩 잘게 내리는 눈 | 조금씩 잘게 내리는 눈 | — | 원본 condition `flurries`·`sunFlurries` | 잔눈 → condition | [표준 385041](https://stdict.korean.go.kr/search/searchView.do?word_no=385041&searchKeywordTo=3) | 지금 「함박눈」이 flurries에도 붙는 문제의 짝 |
| **눈발** | 「2」 눈이 힘차게 내려 줄이 죽죽 져 보이는 상태 | 힘차게 내려 줄이 져 보이는 눈 | — | 원본 condition `snow`·`heavySnow` | 눈이 세게 온다 → condition | [표준 410268](https://stdict.korean.go.kr/search/searchView.do?word_no=410268&searchKeywordTo=3) | 동형어 눈발1(쏘아보는 눈) |
| **눈보라** | 바람에 불리어 휘몰아쳐 날리는 눈 | 바람에 휘몰아쳐 날리는 눈 | `blizzard` | 원본 condition `blowingSnow`·`blizzard` | 바람 + 눈 → condition | [표준 68711](https://stdict.korean.go.kr/search/searchView.do?word_no=68711&searchKeywordTo=3) |  |
| **★밤안개** | 밤에 끼는 안개 | 밤에 끼는 안개 | — | 안개 + 밤 | 밤 안개 → 날씨 + 시각 | [표준 431606](https://stdict.korean.go.kr/search/searchView.do?word_no=431606&searchKeywordTo=3) | 「해미」「안개」「물안개」는 조약돌 이름 |
| **밤눈** | 「2」 밤에 내리는 눈 | 밤에 내리는 눈 | — | 눈 + 밤 | 밤 눈 → 날씨 + 시각 | [표준 141991](https://stdict.korean.go.kr/search/searchView.do?word_no=141991&searchKeywordTo=3) | 동형어 밤눈1(밤 시력) — 뜻풀이로 구분 |
| **바람결** | 일정한 방향으로 부는 바람의 움직임 | 바람이 지나가는 움직임 | — | 바람(`windy`·`breezy`) | 바람이 분다 → 날씨 | [표준 428449](https://stdict.korean.go.kr/search/searchView.do?word_no=428449&searchKeywordTo=3) |  |
| **밤바람** | 밤에 부는 바람 | 밤에 부는 바람 | — | 바람 + 밤 | 밤 바람 → 날씨 + 시각 | [표준 136275](https://stdict.korean.go.kr/search/searchView.do?word_no=136275&searchKeywordTo=3) |  |
| **선들바람** | 가볍고 시원하게 부는 바람 | 가볍고 시원하게 부는 바람 | — | 원본 `breezy` + 기온 15–25°C(제안값) | 가볍고 시원 → breezy + 기온 | [표준 181369](https://stdict.korean.go.kr/search/searchView.do?word_no=181369&searchKeywordTo=3) | 지금 「산들바람」의 정직한 짝 |
| **★꽃샘바람** | 이른 봄 꽃이 필 무렵에 부는 쌀쌀한 바람 | 이른 봄 꽃 필 무렵의 쌀쌀한 바람 | — | 바람 + 3–4월 + 기온 ≤ 10°C(제안값) | 쌀쌀한 봄바람 → 날씨 + 달 + 기온 | [표준 54922](https://stdict.korean.go.kr/search/searchView.do?word_no=54922&searchKeywordTo=3) |  |
| **건들바람** | 초가을에 선들선들 부는 바람 | 초가을에 선들선들 부는 바람 | — | 바람 + 9월 | 초가을 바람 → 날씨 + 달 | [표준 15651](https://stdict.korean.go.kr/search/searchView.do?word_no=15651&searchKeywordTo=3) | 「서늘바람」(182899, 첫가을의 서늘한 바람)도 같은 조건 |
| **칼바람** | 몹시 매섭고 독한 바람 | 몹시 매섭고 독한 바람 | — | 원본 `windy` + 기온 ≤ −5°C(제안값) | 매서운 바람 → windy + 기온 | [표준 338697](https://stdict.korean.go.kr/search/searchView.do?word_no=338697&searchKeywordTo=3) | 「고추바람」(23656, 살을 에는 찬 바람의 비유)도 같은 조건 |

**흐림의 빈칸.** 「흐림」 날씨 하나만으로 붙일 정직한 순우리말 명사는 찾지 못했다. 먹구름·먹장구름(몹시 검은 구름)은 옅은 흐림에 과장이고, 매지구름(비를 머금은 조각구름)·궂은비(오랫동안 내리는 비)는 사진 한 장으로 확인이 안 된다. 형용사를 허용한다면 **끄무레하다**([표준 56892](https://stdict.korean.go.kr/search/searchView.do?word_no=56892&searchKeywordTo=3), 날이 흐리고 어두침침하다)가 있다. 아니면 흐린 날은 봄날·가을날·봄밤 같은 계절 말로 넘기는 게 정직하다.

### B-3. 기온
| 단어 | 사전 뜻풀이(요약) | 앱용 한 줄 뜻 | 붙일 라벨 | 시간대·달·날씨·기온 조건 | 주장하는 사실 → 확인 수단 | 출처 | 비고 |
|---|---|---|---|---|---|---|---|
| **★불볕더위** | 햇볕이 몹시 뜨겁게 내리쬘 때의 더위 | 햇볕이 몹시 뜨겁게 내리쬘 때의 더위 | — | 맑음(`clear`·`mostlyClear`·`hot`) + 기온 ≥ 33°C | 뜨거운 볕 + 더위 → 맑음 + 기온 | [표준 164188](https://stdict.korean.go.kr/search/searchView.do?word_no=164188&searchKeywordTo=3) | 33°C = 기상청 폭염주의보 기준(일 최고 체감 33°C). 「불볕」(436507)도 같은 조건 |
| **가마솥더위** | 가마솥을 달굴 때처럼 몹시 더운 날씨의 비유 | 가마솥을 달군 듯 몹시 더운 날씨 | — | 기온 ≥ 35°C | 몹시 덥다 → 기온 | [표준 833](https://stdict.korean.go.kr/search/searchView.do?word_no=833&searchKeywordTo=3) | 35°C = 기상청 폭염경보 기준 |
| **한더위** | 한창 심한 더위 | 한창 심한 더위 | — | 7–8월 + 기온 ≥ 30°C(제안값) | 한창 덥다 → 달 + 기온 | [표준 368151](https://stdict.korean.go.kr/search/searchView.do?word_no=368151&searchKeywordTo=3) | 「된더위」(517890, 몹시 심한 더위)는 ≥ 33°C로 |
| **늦더위** | 여름이 다 가도록 가시지 않는 더위 | 여름이 다 가도록 가시지 않는 더위 | — | 9월 + 기온 ≥ 28°C(제안값) | 여름 뒤의 더위 → 달 + 기온 | [표준 72738](https://stdict.korean.go.kr/search/searchView.do?word_no=72738&searchKeywordTo=3) |  |
| **땡볕** | 따갑게 내리쬐는 뜨거운 볕 | 따갑게 내리쬐는 뜨거운 볕 | — | 맑음 + 낮·오후 + 기온 ≥ 28°C(제안값) | 따가운 볕 → 맑음 + 시각 + 기온 | [표준 419767](https://stdict.korean.go.kr/search/searchView.do?word_no=419767&searchKeywordTo=3) | 「뙤약볕」(416967)은 「여름날」이 뜻에 있어 6–8월 추가 |
| **★강추위** | 「1」 눈도 오지 않고 바람도 불지 않으면서 몹시 매운 추위 | 눈도 바람도 없이 몹시 매운 추위 | — | 기온 ≤ −10°C + 맑음·흐림(눈·바람 **아님**) | 바람·눈 없는 혹한 → 기온 + 날씨 | [표준 11654](https://stdict.korean.go.kr/search/searchView.do?word_no=11654&searchKeywordTo=3) | 동형어 강추위2(強, 「눈이 오고 매운바람이 부는」)는 정반대 — 뜻풀이로 「1」 고정 |
| **된추위** | 몹시 심한 추위 | 몹시 심한 추위 | — | 기온 ≤ −12°C | 혹한 → 기온 | [표준 92280](https://stdict.korean.go.kr/search/searchView.do?word_no=92280&searchKeywordTo=3) | −12°C = 기상청 한파주의보 기준(아침 최저). 「한추위」(359937)도 같은 조건 |
| **늦추위** | 제철보다 늦게 드는 추위. 또는 겨울이 다 가도록 가시지 않는 추위 | 겨울이 다 가도록 가시지 않는 추위 | — | 3월 + 기온 ≤ 0°C(제안값) | 봄인데 춥다 → 달 + 기온 | [표준 71462](https://stdict.korean.go.kr/search/searchView.do?word_no=71462&searchKeywordTo=3) |  |
| **★잎샘추위** | 봄에 잎이 나올 무렵의 추위 | 봄에 잎이 나올 무렵의 추위 | — | 4월 + 기온 ≤ 5°C(제안값) | 잎 날 무렵 추위 → 달 + 기온 | [표준 515031](https://stdict.korean.go.kr/search/searchView.do?word_no=515031&searchKeywordTo=3) | 「꽃샘추위」(3월)의 짝 |

### B-4. 달(월)
| 단어 | 사전 뜻풀이(요약) | 앱용 한 줄 뜻 | 붙일 라벨 | 시간대·달·날씨·기온 조건 | 주장하는 사실 → 확인 수단 | 출처 | 비고 |
|---|---|---|---|---|---|---|---|
| **첫봄** | 봄이 시작되는 첫머리 | 봄이 시작되는 첫머리 | — | 3월(초순 권장) | 봄 첫머리 → 날짜 | [표준 325496](https://stdict.korean.go.kr/search/searchView.do?word_no=325496&searchKeywordTo=3) | 첫여름(487491)·첫가을(330321)·첫겨울(330326)도 6·9·12월 |
| **★한봄** | 봄이 한창인 때 | 봄이 한창인 때 | — | 4월 | 봄 한창 → 달 | [표준 367287](https://stdict.korean.go.kr/search/searchView.do?word_no=367287&searchKeywordTo=3) | 지금 「한여름」「한겨울」의 짝 |
| **늦봄** | 늦은 봄. 주로 음력 3월을 이른다 | 늦은 봄 | — | 5월 | 늦봄 → 달 | [표준 70655](https://stdict.korean.go.kr/search/searchView.do?word_no=70655&searchKeywordTo=3) | 사전이 「주로 음력 3월」(≈양력 4월 중순–5월 중순)이라 주석 — 5월 상순만 쓰면 양쪽 다 맞음 |
| **★한가을** | 한창 무르익은 가을철 | 한창 무르익은 가을철 | — | 10월 | 가을 한창 → 달 | [표준 501543](https://stdict.korean.go.kr/search/searchView.do?word_no=501543&searchKeywordTo=3) |  |
| **늦가을** | 늦은 가을. 주로 음력 9월을 이른다 | 늦은 가을 | — | 11월 | 늦가을 → 달 | [표준 72687](https://stdict.korean.go.kr/search/searchView.do?word_no=72687&searchKeywordTo=3) | 음력 9월 ≈ 양력 10월 중순–11월 중순 |
| **봄날** | 봄철의 날. 또는 그날의 날씨 | 봄철의 날 | — | 3–5월(때 단어의 마지막 단계) | 봄 → 달 | [표준 147689](https://stdict.korean.go.kr/search/searchView.do?word_no=147689&searchKeywordTo=3) | 가을날(2385)·여름날(459126)·겨울날(396389) 같은 방식. 밋밋하지만 「한나절」보다 계절감이 있음 |

## C. 지금 목록에서 뜻이 사진과 어긋나기 쉬운 말
### C-0. 구조 문제 먼저: 계절이 단계적으로 풀린다
`WordPicker.candidates`는 1단계에서 계절을 따지고, 못 찾으면 2단계 `Check(weather: false, season: false)`에서 **계절 조건을 버린다**. `moment` 쪽도 날씨 말 2단계에서 계절을 버린다. 그래서 이런 일이 생긴다.
- 12월에 꽃 사진: 1단계에 맞는 꽃 말이 없음(산들바람=봄여름가을, 꽃샘추위=봄) → 2단계 → **「꽃샘추위」 또는 바람 없는 날 「산들바람」**.
- 5월에 바람 부는 날, 대상이 안 맞는 사진: 때 단어 중 바람 말은 하늬바람(가을)·된바람(겨울)뿐 → 2단계 → **5월 미풍에 「된바람」(매섭게 부는 북쪽 바람)**.
- 계절은 `seasons`에 넣는 순간 「사실 주장」이 되는 말이 많다. 계절을 풀어도 되는 말과 안 되는 말을 나눠야 한다.

| 단어 | 사전 뜻(근거) | 어긋나는 경우 | 제안 | 출처 |
|---|---|---|---|---|
| **먼동** | 원어 **먼東** — 날이 밝아 올 무렵의 동쪽 | 이번 기준(한자 섞임 제외)에 걸린다. 게다가 새벽 칸 고정이라 12월 06:30(해 높이 −13°)에도 붙음 | 빼거나 예외로 둘지 Tabber 결정. 대체: 첫새벽·어슬녘 | [표준 115323](https://stdict.korean.go.kr/search/searchView.do?word_no=115323&searchKeywordTo=3) |
| **달맞이** | 『민속』 **음력 정월 대보름·팔월 보름** 저녁에 달 뜨기를 기다려 맞는 일 | 1년에 두 밤만 참. 지금은 저녁·밤 달 사진 전부에 붙음 | 음력 날짜 조건(월령 계산으로 가능) 또는 「달밤」으로 교체 | [표준 77575](https://stdict.korean.go.kr/search/searchView.do?word_no=77575&searchKeywordTo=3) |
| **진눈깨비** | 비가 섞여 내리는 눈 | `weathers: [rain]` + 겨울 `moment`라 대상이 안 맞는 **겨울 비 사진 전부**에서 가랑비와 나란히 후보에 오름. 영상 8°C 비에도 | 원본 condition `sleet`·`wintryMix`만 | [표준 311822](https://stdict.korean.go.kr/search/searchView.do?word_no=311822&searchKeywordTo=3) |
| **함박눈** | 굵고 탐스럽게 내리는 눈 | 겨울 눈 날씨면 유일한 후보라 `flurries`(잔눈)에도 붙음. WeatherKit이 없을 땐 `Weather.inferred`가 쌓인 눈 라벨만 보고 「눈」으로 추정해 맑은 날 눈밭 사진에도 붙음 | `snow`·`heavySnow`만, 추정 날씨 제외. 잔눈엔 「가랑눈」 | [표준 365040](https://stdict.korean.go.kr/search/searchView.do?word_no=365040&searchKeywordTo=3) |
| **하늬바람** | **서쪽**에서 부는 바람 | 풍향을 저장하지 않음. 동풍에도 붙음 | 풍향 저장 전까지 빼기 | [표준 363681](https://stdict.korean.go.kr/search/searchView.do?word_no=363681&searchKeywordTo=3) |
| **된바람** | 「1」 매섭게 부는 바람 「2」 뱃사람 말로 북풍 | 앱 뜻 「매섭게 부는 북쪽 바람」이 두 뜻을 섞음. 5월 미풍에도 붙음(C-0) | 뜻을 「1」로, 조건 `windy` + 기온 ≤ 5°C(제안값) | [표준 414983](https://stdict.korean.go.kr/search/searchView.do?word_no=414983&searchKeywordTo=3) |
| **곁두리** | **농사꾼이나 일꾼들이** 끼니 외에 참참이 먹는 음식 | 새참과 같은 문제. 앱 뜻 「끼니 밖에 틈틈이 먹는 음식」은 「일꾼」을 빼서 뜻을 바꿈 | 「군것질」(끼니 외에 과일이나 과자 따위 군음식을 먹는 일)로 교체 + 오후·밤 | [표준 394841](https://stdict.korean.go.kr/search/searchView.do?word_no=394841&searchKeywordTo=3), [군것질 405389](https://stdict.korean.go.kr/search/searchView.do?word_no=405389&searchKeywordTo=3) |
| **새참** | 일을 하다가 잠깐 쉬면서 먹는 음식 | (리드가 짚은 대로) 그냥 점심 사진에 붙음 | 위와 같음 | [표준 182072](https://stdict.korean.go.kr/search/searchView.do?word_no=182072&searchKeywordTo=3) |
| **끼니** | 아침·점심·저녁처럼 날마다 일정한 시간에 먹는 밥 | `night`(20–03:59)가 들어 있어 새벽 2시 라면에도 「끼니」 | 밤 빼고 「밤참」으로 | [표준 57113](https://stdict.korean.go.kr/search/searchView.do?word_no=57113&searchKeywordTo=3) |
| **한밤** | 깊은 밤(=한밤중) | 밤 칸이 20시부터라 저녁 8시에도 「깊은 밤」 | 23–02시 | [표준 367654](https://stdict.korean.go.kr/search/searchView.do?word_no=367654&searchKeywordTo=3) |
| **땅거미** | **해가 진 뒤** 어스레한 상태 | 7월 17:30은 해 높이 26° | 해 진 뒤(고도 < 0°)만 | [표준 94605](https://stdict.korean.go.kr/search/searchView.do?word_no=94605&searchKeywordTo=3) |
| **해거름** | 해가 서쪽으로 넘어가는 일. 또는 그런 때 | 여름 17시엔 한낮처럼 밝음. 반대로 12월 16:50(오후 칸, 해 높이 3°)엔 진짜 해거름인데 안 붙음 | 태양 고도 기준으로 바꾸면 오후 칸 빈자리도 채움 | [표준 502415](https://stdict.korean.go.kr/search/searchView.do?word_no=502415&searchKeywordTo=3) |
| **윤슬** | **햇빛이나 달빛에** 비치어 반짝이는 잔물결 | 지금 `times`·`weathers`가 비어 있어 비 오는 날·달 없는 밤 물 사진에도 붙음 | (맑음 + 아침·낮·오후) 또는 (밤 + `moon`) | [표준 466701](https://stdict.korean.go.kr/search/searchView.do?word_no=466701&searchKeywordTo=3) |
| **꽃샘추위** | 이른 봄, 꽃이 필 무렵의 **추위** | 기온 조건 없음 + 계절 풀림 → 12월 꽃, 20°C 4월 꽃에도 | 3–4월 + 기온 ≤ 5°C(제안값), 계절 풀지 않기 | [표준 404396](https://stdict.korean.go.kr/search/searchView.do?word_no=404396&searchKeywordTo=3) |
| **산들바람** | 시원하고 가볍게 부는 **바람** | 바람 조건이 없어 바람 없는 날 꽃·풀 사진에 붙음 | 원본 `breezy` | [표준 441368](https://stdict.korean.go.kr/search/searchView.do?word_no=441368&searchKeywordTo=3) |
| **아지랑이** | 주로 봄날 **햇빛이 강하게 쬘 때** 공기가 아른아른 움직이는 현상 | 날씨 조건 없음 → 봄비 내리는 낮 길 사진에도 | 맑음 + 기온 ≥ 18°C(제안값) | [표준 222933](https://stdict.korean.go.kr/search/searchView.do?word_no=222933&searchKeywordTo=3) |
| **한여름 / 한겨울** | **더위가 / 추위가** 한창인 여름 / 겨울 | 계절 전체(6월 1일, 2월 말)에 붙음 | 7–8월 + ≥ 28°C / 12–1월 + ≤ 0°C(제안값) | [표준 505190](https://stdict.korean.go.kr/search/searchView.do?word_no=505190&searchKeywordTo=3), [360412](https://stdict.korean.go.kr/search/searchView.do?word_no=360412&searchKeywordTo=3) |
| **찬바람머리** | 가을철에 싸늘한 바람이 불기 **시작할 무렵** | 9월 1일 30°C에도 | 9월 하순–10월 + 기온 ≤ 18°C(제안값) | [표준 317773](https://stdict.korean.go.kr/search/searchView.do?word_no=317773&searchKeywordTo=3) |
| **먹장구름** | 먹빛같이 **시꺼먼** 구름 | 흐림 `moment`라 옅은 흐림에도 | 비·뇌우일 때만 | [표준 114121](https://stdict.korean.go.kr/search/searchView.do?word_no=114121&searchKeywordTo=3) |
| **여우비** | 볕이 나 있는 날 잠깐 오다가 그치는 비 | 비 + 파란 하늘 라벨로 근사 중 | WeatherKit `sunShowers`가 정확히 이 현상 | [표준 233705](https://stdict.korean.go.kr/search/searchView.do?word_no=233705&searchKeywordTo=3) |
| **샛별** | 금성 | 사진으로 금성 확인 불가(개밥바라기와 같은 이유) | 빼기 | [표준 439361](https://stdict.korean.go.kr/search/searchView.do?word_no=439361&searchKeywordTo=3) |
| **무서리** | 늦가을에 **처음** 내리는 묽은 서리 | 서리가 있는지, 처음인지 둘 다 확인 불가 | 빼거나 10–11월 + 새벽·아침 + ≤ 2°C로 약하게 | [표준 423390](https://stdict.korean.go.kr/search/searchView.do?word_no=423390&searchKeywordTo=3) |
| **골목** | 큰길에서 들어가 동네 안을 통하는 **좁은 길** | `street`(큰길)에도 붙음 | `alley`만 | [표준 397158](https://stdict.korean.go.kr/search/searchView.do?word_no=397158&searchKeywordTo=3) |
| **길섶** | **길의** 가장자리. 흔히 풀이 나 있는 곳 | OR 매칭이라 풀만 찍혀도 「길섶」 | 길 라벨 AND 풀 라벨 | [표준 51019](https://stdict.korean.go.kr/search/searchView.do?word_no=51019&searchKeywordTo=3) |
| **말벗** | 더불어 이야기할 만한 **친구** | `people`만으로 관계를 주장. 군중 사진에도 | 빼기 | [표준 111410](https://stdict.korean.go.kr/search/searchView.do?word_no=111410&searchKeywordTo=3) |
| **손때** | **오랫동안** 쓰고 매만져 길이 든 흔적 | 새 책·새 책상에도 | 빼기 | [표준 194986](https://stdict.korean.go.kr/search/searchView.do?word_no=194986&searchKeywordTo=3) |
| **짬 / 겨를** | 짬: 일에서 손을 떼거나 다른 일에 손을 댈 수 있는 겨를 / 겨를: 생각을 다른 데로 돌릴 수 있는 시간적 여유 | `laptop`·`computer`는 오히려 일하는 중 | `cup`·`coffee`만 남기거나 빼기 | [표준 486750](https://stdict.korean.go.kr/search/searchView.do?word_no=486750&searchKeywordTo=3) |
| **비설거지** | 비가 오려 하거나 올 때 젖으면 안 될 물건을 **치우거나 덮는 일** | 행동을 주장. 우산 사진으론 확인 불가 | 빼기 | [표준 434953](https://stdict.korean.go.kr/search/searchView.do?word_no=434953&searchKeywordTo=3) |
| **물보라** | 물결이 바위 따위에 **부딪쳐 흩어지는** 물방울 | 잔잔한 바다·호수에도 | `waterfall`·`surfing`만 | [표준 424761](https://stdict.korean.go.kr/search/searchView.do?word_no=424761&searchKeywordTo=3) |
| **볕바라기·햇발** | 볕을 쬐는 일 / 사방으로 뻗친 햇살 | 날씨 조건이 없어 비 오는 날 창가 사진에도. 볕바라기는 **표준국어대사전에 없음**(우리말샘만) | 맑음 조건 | [우리말샘 볕바라기](https://opendict.korean.go.kr/search/searchResult?query=%EB%B3%95%EB%B0%94%EB%9D%BC%EA%B8%B0), [표준 502498](https://stdict.korean.go.kr/search/searchView.do?word_no=502498&searchKeywordTo=3) |
| **모꼬지** | 놀이나 잔치로 **여러 사람이** 모이는 일 | `celebration`만(케이크 한 조각)으로도 | `celebration` AND `people` | [표준 118112](https://stdict.korean.go.kr/search/searchView.do?word_no=118112&searchKeywordTo=3) |
| **한나절** | 하룻낮의 반 | 거짓은 아니나 「동안」을 말해 순간과 안 맞고, Tabber가 가장 많이 버림 | 낮때·낮곁·볕 말이 먼저 나오게 | [표준 360504](https://stdict.korean.go.kr/search/searchView.do?word_no=360504&searchKeywordTo=3) |

## 미확인 · 제외
### 미확인 (두 사전 어디에도 한 단어로 없음 → 추천 안 함)
칼추위, 날밝이, 밝을녘, 하늘금, 저녁곁, 우레비, 해질녘(우리말샘 참여자 제안만, 전문가 감수 0 — 표준 표기는 「해 질 녘」 띄어 씀), 이른봄(띄어 씀), 손글씨(우리말샘에 「손 글씨」 두 단어로만).

### 제외 — 한자·외래어가 섞임
| 말 | 근거 |
|---|---|
| 처마 | 원어란은 비었지만 어원 「첨하 ← 檐牙」 |
| 썰매 | 어원 「雪馬」 |
| 천둥 | 어원 「텬동 ← 天動」 (→ 「우레」 사용) |
| 냄비 | 어원 일본어 「nabe」 |
| 접시 | 어원 「楪子」 |
| 젓가락·수저 | 어원 「져+ㅅ+가락」, 「술+져」 — 사전 어원란엔 한자가 안 찍히지만 「져」는 箸(젓가락 저)라 의심. 보류 |
| 장대비 | 長대비 (→ 같은 뜻 「작달비」) |
| 동살·동트기·먼동 | 東살·東트기·먼東 |
| 구름장 | 구름張 |
| 왜바람 | 倭바람 |
| 산바람·산등성이·용마루 | 山·山·龍 |
| 강바람(강물 위) | 江바람. 단, 동형어 「강바람1」(비 없이 심하게 부는 바람)은 고유어 — 표기로 구분이 안 돼 보류 |
| 바람기 | 바람氣. 게다가 「이성 관계의 바람」 뜻이 먼저 떠오름 |
| 세밑·해토머리·손돌이추위·밤중 | 歲·解土·孫乭·中 |
| 항아리 | 缸아리 |
| 벙어리장갑·손모아장갑 | 掌匣(장갑). 벙어리는 차별어 문제도 있음 |
| 찜통더위 | 사전 원어 표시 없음. 그러나 「통」이 桶일 가능성 — 보류(「가마솥더위」 사용) |

### 제외 — 사진으로 확인할 수 없거나 뜻이 어긋남
| 말 | 왜 | 출처 |
|---|---|---|
| 강아지 | 「개의 새끼」. 다 큰 개에 거짓 | [표준 388677](https://stdict.korean.go.kr/search/searchView.do?word_no=388677&searchKeywordTo=3) |
| 홀씨 | 「포자」. 민들레 씨를 「홀씨」라 부르는 건 오용 | [표준 375060](https://stdict.korean.go.kr/search/searchView.do?word_no=375060&searchKeywordTo=3) |
| 들꽃 | 「들에 피는 꽃」 — 꽃병·화분 꽃에 거짓(→ 풀꽃) | [표준 417910](https://stdict.korean.go.kr/search/searchView.do?word_no=417910&searchKeywordTo=3) |
| 꽃망울 | 「아직 피지 아니한」 — 봉오리인지 판별 불가 | [표준 406070](https://stdict.korean.go.kr/search/searchView.do?word_no=406070&searchKeywordTo=3) |
| 쪽배 | 「통나무를 쪼개어 속을 파서 만든」 — 카누·카약에 거짓 | [표준 488471](https://stdict.korean.go.kr/search/searchView.do?word_no=488471&searchKeywordTo=3) |
| 밥집 | 「싼값에 파는 집」 — 레스토랑 전반에 거짓 | [표준 136637](https://stdict.korean.go.kr/search/searchView.do?word_no=136637&searchKeywordTo=3) |
| 바구니·소쿠리·광주리 | 「대나 싸리 따위를 쪼개어 결어」 — 플라스틱 바구니에 거짓 | [표준 428754](https://stdict.korean.go.kr/search/searchView.do?word_no=428754&searchKeywordTo=3) |
| 울타리 | 「풀이나 나무 따위를 얽거나 엮어서」 — 쇠 펜스에 거짓 | [표준 250791](https://stdict.korean.go.kr/search/searchView.do?word_no=250791&searchKeywordTo=3) |
| 못(연못) | 「늪보다 작다」 — `lake`엔 크기가 안 맞고 동형어(쇠못·굳은살)도 많음 | [표준 120656](https://stdict.korean.go.kr/search/searchView.do?word_no=120656&searchKeywordTo=3) |
| 텃밭 | 「집 가까이 있는 밭」 — 위치 확인 불가(→ 남새밭) | [표준 494493](https://stdict.korean.go.kr/search/searchView.do?word_no=494493&searchKeywordTo=3) |
| 몽돌 | 「모가 나지 않고 둥근 돌」 — 앱 이름과 같음 | [표준 423030](https://stdict.korean.go.kr/search/searchView.do?word_no=423030&searchKeywordTo=3) |
| 비꽃 | 우리말샘 「북한어」. 비가 **시작할 때**라 확인 불가 | [우리말샘](https://opendict.korean.go.kr/search/searchResult?query=%EB%B9%84%EA%BD%83) |
| 신새벽 | 사전이 비표준어로 둠(→ 첫새벽) | [표준 487506](https://stdict.korean.go.kr/search/searchView.do?word_no=487506&searchKeywordTo=3) |
| 실바람 | 풍력 계급 1(초속 0.3–1.5m) — 앱 「바람」 날씨(`windy`·`breezy`)와 모순 | [표준 203028](https://stdict.korean.go.kr/search/searchView.do?word_no=203028&searchKeywordTo=3) |
| 황소바람·살바람 | 「좁은 틈으로」 드는 바람 — 실내 외풍 | [표준 382503](https://stdict.korean.go.kr/search/searchView.do?word_no=382503&searchKeywordTo=3) |
| 마파람·샛바람·높새바람 | 남풍·동풍·동북풍 — 풍향 미저장 | [표준 417210](https://stdict.korean.go.kr/search/searchView.do?word_no=417210&searchKeywordTo=3) |
| 갯바람·바닷바람 | 「바다에서 육지로」 — 풍향 필요 | [표준 11206](https://stdict.korean.go.kr/search/searchView.do?word_no=11206&searchKeywordTo=3) |
| 첫눈·첫추위·첫더위·첫서리 | 「그해 처음」 — 지난 기록이 있어야 함(앱 자체 기록으로 언젠가 가능) | [표준 489489](https://stdict.korean.go.kr/search/searchView.do?word_no=489489&searchKeywordTo=3) |
| 장마·궂은비·강더위 | 「여러 날」「오랫동안」 — 사진 한 장의 날씨로 불가 | [표준 276808](https://stdict.korean.go.kr/search/searchView.do?word_no=276808&searchKeywordTo=3) |
| 비거스렁이 | 「비가 갠 뒤」 바람·기온 하강 — 시계열 필요 | [표준 438038](https://stdict.korean.go.kr/search/searchView.do?word_no=438038&searchKeywordTo=3) |
| 단비 | 「꼭 필요한 때」 — 주관 | [표준 75174](https://stdict.korean.go.kr/search/searchView.do?word_no=75174&searchKeywordTo=3) |
| 도둑눈·숫눈·싸라기눈 | 「사람들이 모르게」·「쌓인 그대로」·「쌀알 같은」 — 확인 불가 | [표준 83933](https://stdict.korean.go.kr/search/searchView.do?word_no=83933&searchKeywordTo=3) |
| 상고대·성에·밤이슬·서릿발 | 서리·이슬이 있는지 Vision 라벨로 알 수 없음 | [표준 173379](https://stdict.korean.go.kr/search/searchView.do?word_no=173379&searchKeywordTo=3) |
| 섣달 | 「**음력**으로 한 해의 맨 끝 달」 — 양력 12월은 대부분 음력 11월 | [표준 185587](https://stdict.korean.go.kr/search/searchView.do?word_no=185587&searchKeywordTo=3) |
| 별밤·잔별 | 별이 보이는지 확인 불가(도시 빛 공해) | [우리말샘](https://opendict.korean.go.kr/search/searchResult?query=%EB%B3%84%EB%B0%A4) |
| 아침참·새벽잠·밤샘·한뎃잠 | 쉬는 중·자는 중·밤새는 중 — 행동 주장 | [표준 216542](https://stdict.korean.go.kr/search/searchView.do?word_no=216542&searchKeywordTo=3) |
| 한데 | 「집채의 바깥」 — `outdoor` 단독 근거라 제외 | [표준 368165](https://stdict.korean.go.kr/search/searchView.do?word_no=368165&searchKeywordTo=3) |
| 옷맵시 | 「옷이 어울리는」 — 평가라 확인 불가(→ 차림새) | [표준 459711](https://stdict.korean.go.kr/search/searchView.do?word_no=459711&searchKeywordTo=3) |

### 보류 — 고운데 동형이의가 걸리는 말 (Tabber 판단)
- **물놀이1** — 「잔잔한 물이 공기의 움직임을 받아 수면에 잔물결이 이는 현상」. 윤슬의 흐린 날 짝으로 아름답지만, 누구나 「물놀이2」(물에서 노는 일)로 읽는다. [표준 126997](https://stdict.korean.go.kr/search/searchView.do?word_no=126997&searchKeywordTo=3)
- **놀이2** — 「봄날에 벌들이 떼를 지어 제집 앞에 나와 날아다니는 일」. `bee`·`beehive` + 봄. 「놀이1」과 혼동된다. [표준 67915](https://stdict.korean.go.kr/search/searchView.do?word_no=67915&searchKeywordTo=3)
- **날궂이3** — 「궂은 날씨에 음식을 장만하여 서로 나누어 먹거나 소일거리로 시간을 보냄」. 비 오는 날 음식 사진에 딱이지만 1·2뜻(쓸데없는 짓, 날 궂기 전 몸이 쑤심)이 부정적이다. [표준 533975](https://stdict.korean.go.kr/search/searchView.do?word_no=533975&searchKeywordTo=3)
- **강바람1** — 「비는 내리지 아니하고 심하게 부는 바람」. 앱 조건과 꼭 맞지만 대부분 江바람으로 읽는다. [표준 9019](https://stdict.korean.go.kr/search/searchView.do?word_no=9019&searchKeywordTo=3)
- **마른번개** — 「맑게 갠 하늘에서 치는 번개」. `lightning` + 맑음. 정확하지만 그런 사진이 드물다. [표준 418307](https://stdict.korean.go.kr/search/searchView.do?word_no=418307&searchKeywordTo=3)
