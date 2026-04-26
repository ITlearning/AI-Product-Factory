export const curriculum = [
  {
    "id": "kotlin-val-vs-var",
    "title_en": "Variables and Constants (val, var)",
    "title_ko": "변수와 상수 (val, var)",
    "level": "beginner",
    "category": "Kotlin Basics",
    "order": 1,
    "tip_ko": "기본은 val. 정말 변경이 필요할 때만 var를 써요. 불변이 안전합니다.",
    "tip_en": "Default to val. Use var only when mutation is required. Immutability is safer.",
    "teaching_hints_ko": {
      "what": "이름이 붙은 데이터 저장 공간. val은 한 번 정하면 다시 못 바꾸고, var는 바꿀 수 있어요.",
      "why": "데이터를 기억하고 다시 쓰기 위해 필요. val이 기본인 이유는 의도치 않은 변경을 막아 버그를 줄여줍니다.",
      "how": "val name = \"Spring\"\nvar count = 0\ncount += 1",
      "watchOut": "val 변수에 다시 대입하면 컴파일 에러. 다만 객체의 내부 필드는 변경 가능 — 참조 자체는 못 바꿔도 객체 상태는 바뀔 수 있어요."
    },
    "teaching_hints_en": {
      "what": "Named storage for data. val is read-only after initialization, var is mutable.",
      "why": "Lets you remember and reuse data. val is preferred because it prevents accidental mutations and reduces bugs.",
      "how": "val name = \"Spring\"\nvar count = 0\ncount += 1",
      "watchOut": "Reassigning a val causes a compile error. However, mutating fields inside an object held by val is allowed — the reference is fixed, not the inner state."
    },
    "analogies_ko": [
      "val은 도장 찍힌 인감, var는 연필로 쓴 메모"
    ],
    "analogies_en": [
      "val is a notarized signature, var is a pencil note"
    ],
    "simpler_fallback": null
  },
  {
    "id": "kotlin-null-safety",
    "title_en": "Null Safety",
    "title_ko": "Null 안전성",
    "level": "beginner",
    "category": "Kotlin Basics",
    "order": 2,
    "tip_ko": "타입에 ?를 붙이면 null 가능, 안 붙이면 null 불가. !! 연산자는 가급적 피하세요.",
    "tip_en": "Type with `?` allows null, without it forbids null. Avoid the `!!` operator when possible.",
    "teaching_hints_ko": {
      "what": "변수가 null이 될 수 있는지를 타입에서 명시. String?은 null 가능, String은 null 불가.",
      "why": "Java의 NullPointerException(NPE)을 컴파일 타임에 잡아내서 런타임 오류를 크게 줄여줘요.",
      "how": "val nullable: String? = null\nval safe: String = \"hello\"\nnullable?.length  // null이면 null 반환\nnullable ?: \"default\"  // null이면 \"default\"",
      "watchOut": "!! 연산자는 null일 때 강제로 NPE를 던져요. 정말 null이 아닌 게 확실할 때만 사용. 일반적으론 ?. 와 ?: 조합으로 안전 처리."
    },
    "teaching_hints_en": {
      "what": "Express whether a variable can hold null in the type itself. String? permits null, String forbids it.",
      "why": "Catches Java's NullPointerException at compile time, dramatically reducing runtime errors.",
      "how": "val nullable: String? = null\nval safe: String = \"hello\"\nnullable?.length  // returns null if null\nnullable ?: \"default\"  // \"default\" if null",
      "watchOut": "!! throws NPE on null. Use only when you're certain it's non-null. Prefer ?. and ?: for safety."
    },
    "analogies_ko": [
      "편지봉투에 '내용 없을 수 있음' 도장 찍어두는 것. 받는 사람이 미리 알고 열어요.",
      "공항 신원확인: ?는 '여권 없을 수도', !!는 '여권 없으면 무조건 튕김'"
    ],
    "analogies_en": [
      "A clearly labeled package: '?' means 'might be empty', so the receiver checks first.",
      "Passport check: ?. is 'maybe', !! is 'must have or fail'"
    ],
    "simpler_fallback": "kotlin-val-vs-var"
  },
  {
    "id": "kotlin-data-class",
    "title_en": "Data Classes",
    "title_ko": "데이터 클래스 (data class)",
    "level": "beginner",
    "category": "Kotlin Basics",
    "order": 3,
    "tip_ko": "DTO나 값 객체는 data class로. equals/hashCode/toString/copy를 자동 생성해줘요.",
    "tip_en": "Use data class for DTOs and value objects. It auto-generates equals/hashCode/toString/copy.",
    "teaching_hints_ko": {
      "what": "주 생성자에 정의된 프로퍼티들 기준으로 equals, hashCode, toString, copy, componentN을 컴파일러가 만들어주는 클래스.",
      "why": "Java POJO 보일러플레이트(getter/setter/equals/hashCode) 제거. 의미는 그대로, 코드는 한 줄.",
      "how": "data class User(val id: Long, val name: String)\nval u = User(1, \"Tabber\")\nval u2 = u.copy(name = \"Anna\")  // 일부만 바꾼 복사본",
      "watchOut": "data class끼리 equals는 프로퍼티 값 기준. 참조 비교는 ===. 상속이 제한적이라 보통 final로 사용해요."
    },
    "teaching_hints_en": {
      "what": "A class where the compiler auto-generates equals, hashCode, toString, copy, and componentN based on the primary constructor properties.",
      "why": "Eliminates Java POJO boilerplate (getter/setter/equals/hashCode). Same meaning, one line of code.",
      "how": "data class User(val id: Long, val name: String)\nval u = User(1, \"Tabber\")\nval u2 = u.copy(name = \"Anna\")  // partial copy",
      "watchOut": "Equality is by property values. Use === for reference comparison. Inheritance is restricted, so they're usually final."
    },
    "analogies_ko": [
      "엑셀 한 줄 같은 것 — 컬럼(프로퍼티)들이 모인 한 행. 두 행이 같은지는 컬럼 값으로 판단."
    ],
    "analogies_en": [
      "Like a row in a spreadsheet — fields are columns. Two rows are equal if their values match."
    ],
    "simpler_fallback": "kotlin-val-vs-var"
  },
  {
    "id": "kotlin-string-template",
    "title_en": "String Templates",
    "title_ko": "문자열 템플릿",
    "level": "beginner",
    "category": "Kotlin Basics",
    "order": 4,
    "tip_ko": "$변수 또는 ${'$'}{표현식}으로 문자열에 값을 끼워넣어요. + 연결보다 가독성 좋아요.",
    "tip_en": "Embed values with $variable or ${'$'}{expression}. More readable than + concatenation.",
    "teaching_hints_ko": {
      "what": "큰따옴표 문자열 안에서 $변수 또는 ${'$'}{표현식}이 자동으로 toString() 결과로 치환됨.",
      "why": "Java처럼 \"hello \" + name + \", you have \" + count + \" items\" 안 쓰고 한 줄로. 가독성과 안전성 모두 향상.",
      "how": "val name = \"Tabber\"\nval count = 5\nval msg = \"Hi $name, you have ${'$'}{count + 1} items\"",
      "watchOut": "$ 자체를 출력하려면 \\$로 escape. 복잡한 표현식은 ${'$'}{} 안에. 객체를 끼우면 toString() 결과가 나가니까 의미 있는 toString() 직접 정의 권장."
    },
    "teaching_hints_en": {
      "what": "Inside double-quoted strings, $variable or ${'$'}{expression} is auto-replaced with the toString() output.",
      "why": "Instead of \"hello \" + name + \", you have \" + count + \" items\", write \"hello $name, you have $count items\" — one line, more readable, fewer mistakes.",
      "how": "val name = \"Tabber\"\nval count = 5\nval msg = \"Hi $name, you have ${'$'}{count + 1} items\"",
      "watchOut": "Escape literal $ with \\$. Use ${'$'}{...} for complex expressions. Custom objects without a meaningful toString() will print class@hashcode — define toString() explicitly."
    },
    "analogies_ko": [
      "편지 양식의 빈칸 채우기 — 미리 정해둔 위치에 자동으로 값이 들어감."
    ],
    "analogies_en": [
      "Mail merge — predefined slots in a template that auto-fill with your data."
    ],
    "simpler_fallback": "kotlin-val-vs-var"
  },
  {
    "id": "kotlin-collection-basics",
    "title_en": "Collections (List, Map, Set)",
    "title_ko": "컬렉션 기초 (List, Map, Set)",
    "level": "beginner",
    "category": "Kotlin Basics",
    "order": 5,
    "tip_ko": "기본은 immutable: listOf, mapOf, setOf. 변경 필요하면 mutableXxxOf. immutable이 안전합니다.",
    "tip_en": "Default to immutable: listOf, mapOf, setOf. Use mutableXxxOf when you need to mutate. Immutable is safer.",
    "teaching_hints_ko": {
      "what": "여러 값을 묶어 다루는 자료구조. List는 순서 있고 중복 허용, Set은 순서 없고 유일, Map은 키-값 쌍.",
      "why": "Java처럼 매번 ArrayList<String>() 안 만들어도 됨. Kotlin은 immutable이 기본이라 의도치 않은 변경 차단.",
      "how": "val nums = listOf(1, 2, 3)\nval scores = mapOf(\"swift\" to 90, \"kotlin\" to 95)\nval mutable = mutableListOf<String>()\nmutable.add(\"hi\")",
      "watchOut": "listOf로 만든 List에 add 호출하면 컴파일 에러. 가변 필요하면 mutableListOf로. immutable List는 read-only view라 내부적으론 변경 가능한 컬렉션을 가리키고 있을 수 있음."
    },
    "teaching_hints_en": {
      "what": "Data structures for grouping values. List is ordered with duplicates, Set is unordered and unique, Map holds key-value pairs.",
      "why": "No need to write ArrayList<String>() every time. Kotlin defaults to immutable, blocking unintended mutations.",
      "how": "val nums = listOf(1, 2, 3)\nval scores = mapOf(\"swift\" to 90, \"kotlin\" to 95)\nval mutable = mutableListOf<String>()\nmutable.add(\"hi\")",
      "watchOut": "Calling .add on a listOf result is a compile error. Use mutableListOf for mutability. Note: immutable List is a read-only view — the underlying collection might still be mutable elsewhere."
    },
    "analogies_ko": [
      "List = 줄 선 사람들 (순서 ○, 중복 ○), Set = 동아리 가입자 명단 (중복 X), Map = 사전 (단어 → 뜻)"
    ],
    "analogies_en": [
      "List = people in a queue (ordered, duplicates ok), Set = a club's roster (no duplicates), Map = a dictionary (word → definition)"
    ],
    "simpler_fallback": null
  },
  {
    "id": "kotlin-scope-functions",
    "title_en": "Scope Functions",
    "title_ko": "스코프 함수 (let, run, apply, also, with)",
    "level": "basic",
    "category": "Kotlin Basics",
    "order": 6,
    "tip_ko": "객체 설정은 apply, null 체크 후 변환은 let. 결과 vs 객체, this vs it만 구분하면 끝.",
    "tip_en": "apply for setup, let for null-checked transforms. Just distinguish result vs object, this vs it.",
    "teaching_hints_ko": {
      "what": "객체를 람다 블록 안에서 잠깐 다루도록 해주는 함수들. 람다 안에서 객체를 this로 받느냐 it으로 받느냐, 반환값이 객체 자신이냐 람다 결과냐로 5가지로 나뉘어요.",
      "why": "임시 변수 안 만들고 체이닝으로 깔끔하게 처리. null 체크, 객체 초기화, 디버깅 로그 끼워넣기 같은 패턴이 한 줄로 정리돼요.",
      "how": "val user = User().apply {\n  name = \"Tabber\"\n  age = 30\n}  // apply: 객체 자신 반환\n\nval len = user.name?.let { it.length } ?: 0\n// let: null 아닐 때만 블록 실행, 결과 반환",
      "watchOut": "5개 다 외우려 하면 헷갈려요. 실전에선 apply(설정)와 let(null 가드)이 80%. also는 디버깅용 println에 꽂아쓰기 좋고, run/with는 잘 안 써도 돼요. 중첩하면 this가 누구를 가리키는지 헷갈리니 한 단계만."
    },
    "teaching_hints_en": {
      "what": "Helpers that briefly let you operate on an object inside a lambda. They differ in two axes: receiver as this vs it, and return the object itself vs the lambda result.",
      "why": "Eliminate temporary variables and chain operations cleanly. Null guards, object setup, and inline logging collapse into one expression.",
      "how": "val user = User().apply {\n  name = \"Tabber\"\n  age = 30\n}  // apply returns the object\n\nval len = user.name?.let { it.length } ?: 0\n// let runs only when non-null, returns lambda result",
      "watchOut": "Memorizing all five is overkill. In practice apply (setup) and let (null guard) cover 80%. also is great for inline logging; run/with are rarely needed. Nesting them muddles what this refers to — keep it one level deep."
    },
    "analogies_ko": [
      "편의점 결제 — apply는 '카드에 도장 찍고 카드 돌려줌', let은 '카드 받아서 영수증만 돌려줌'. 돌려주는 게 뭐냐의 차이."
    ],
    "analogies_en": [
      "At a coffee counter — apply is 'stamp the card and hand the card back', let is 'take the card and hand back a receipt'. Difference is what you get back."
    ],
    "simpler_fallback": "kotlin-data-class"
  },
  {
    "id": "kotlin-when-expression",
    "title_en": "when Expression",
    "title_ko": "when 표현식",
    "level": "basic",
    "category": "Kotlin Basics",
    "order": 7,
    "tip_ko": "when은 값을 반환하는 표현식. sealed class와 함께 쓰면 컴파일러가 빠진 케이스를 잡아줘요.",
    "tip_en": "when is an expression that returns a value. Combined with sealed classes, the compiler catches missing cases.",
    "teaching_hints_ko": {
      "what": "Java switch의 강화판. 값 비교뿐 아니라 타입 체크, 범위, 임의 조건까지 분기 가능. 결과를 변수에 바로 대입할 수 있는 표현식이에요.",
      "why": "if-else 사다리, instanceof 체크, switch fallthrough 버그를 한 번에 정리. 값을 반환하니 변수 초기화에 그대로 쓸 수 있어요.",
      "how": "val label = when (x) {\n  0 -> \"zero\"\n  in 1..9 -> \"single\"\n  is Int -> \"int $x\"\n  else -> \"other\"\n}",
      "watchOut": "표현식으로 쓸 땐 else가 필수 (sealed class면 예외). 화살표 -> 다음에 블록 쓰면 마지막 줄이 결과값. 콤마로 케이스 합칠 때 (1, 2, 3 ->) 범위 in과 헷갈리지 마세요."
    },
    "teaching_hints_en": {
      "what": "A souped-up switch. Branches on values, types, ranges, or arbitrary conditions. As an expression, it returns a value you can assign directly.",
      "why": "Replaces if-else ladders, instanceof checks, and fallthrough-prone switch statements. Returning a value means you can initialize variables in one shot.",
      "how": "val label = when (x) {\n  0 -> \"zero\"\n  in 1..9 -> \"single\"\n  is Int -> \"int $x\"\n  else -> \"other\"\n}",
      "watchOut": "Used as an expression, else is required (unless the subject is sealed and exhaustive). With block bodies after ->, the last line is the result. Don't confuse comma-separated cases (1, 2, 3 ->) with the in operator for ranges."
    },
    "analogies_ko": [
      "우체국 분류기 — 무게로, 지역으로, 등기 여부로 한 봉투를 여러 기준에 따라 자동 분류. 마지막엔 '기타' 통이 꼭 있어야 해요."
    ],
    "analogies_en": [
      "A postal sorter — routes envelopes by weight, region, or registered status. There's always a 'misc' bin at the end."
    ],
    "simpler_fallback": "kotlin-val-vs-var"
  },
  {
    "id": "kotlin-extension-functions",
    "title_en": "Extension Functions",
    "title_ko": "확장 함수 (Extension Functions)",
    "level": "basic",
    "category": "Kotlin Basics",
    "order": 8,
    "tip_ko": "남의 클래스에 메서드를 '얹는' 기능. 정적 디스패치라서 다형성은 안 돼요.",
    "tip_en": "Adds methods to types you don't own. Resolved statically — no polymorphism.",
    "teaching_hints_ko": {
      "what": "기존 클래스를 상속·수정 안 하고 새 메서드를 붙여 쓰는 문법. 실제론 첫 인자가 receiver인 정적 함수로 컴파일돼요.",
      "why": "유틸 클래스(StringUtils.toSlug(s)) 대신 자연스러운 메서드 호출(s.toSlug())로 쓸 수 있어요. 코드가 영어 문장처럼 읽혀요.",
      "how": "fun String.toSlug(): String =\n  this.lowercase()\n    .replace(\" \", \"-\")\n\nval url = \"Hello World\".toSlug()\n// \"hello-world\"",
      "watchOut": "정적 디스패치라 부모 타입 변수에 자식 객체를 담아 호출하면 부모 쪽 확장이 불려요 — virtual override 아님. private/protected 멤버 접근 불가. 같은 시그니처 멤버 함수가 있으면 멤버가 이김."
    },
    "teaching_hints_en": {
      "what": "Adds methods to existing types without inheritance or modification. Compiles to a static function whose first argument is the receiver.",
      "why": "Replace utility classes (StringUtils.toSlug(s)) with natural method calls (s.toSlug()). Code reads like an English sentence.",
      "how": "fun String.toSlug(): String =\n  this.lowercase()\n    .replace(\" \", \"-\")\n\nval url = \"Hello World\".toSlug()\n// \"hello-world\"",
      "watchOut": "Resolved statically: calling on a parent-typed variable picks the parent's extension, not the child's — no virtual override. Can't touch private/protected members. A member function with the same signature wins over an extension."
    },
    "analogies_ko": [
      "남의 가방에 내 이니셜 스티커 붙이는 거예요. 가방 본체는 안 바꿨는데 내 거처럼 부를 수 있음. 단, 가방 안 잠금장치는 못 열어요."
    ],
    "analogies_en": [
      "Slapping your own sticker on someone else's notebook. You didn't change the notebook, but you can refer to it as yours — though you still can't open its locked compartments."
    ],
    "simpler_fallback": "kotlin-data-class"
  },
  {
    "id": "kotlin-sealed-class",
    "title_en": "Sealed Classes",
    "title_ko": "봉인 클래스 (sealed class)",
    "level": "intermediate",
    "category": "Kotlin Advanced",
    "order": 9,
    "tip_ko": "상태(Loading/Success/Error) 모델링은 sealed class. when에서 else 없이도 컴파일러가 빠진 케이스를 잡아줘요.",
    "tip_en": "Model states (Loading/Success/Error) with sealed classes. when without else still gets exhaustiveness checks.",
    "teaching_hints_ko": {
      "what": "하위 타입을 같은 모듈/패키지 안으로 제한한 추상 클래스. 컴파일러가 모든 자식을 알기 때문에 when을 exhaustive하게 검사해줘요.",
      "why": "enum은 같은 데이터 모양을 공유해야 하는데, sealed는 각 케이스가 다른 필드를 가질 수 있어요. UI 상태, API 응답, 에러 분기에 딱.",
      "how": "sealed class UiState {\n  object Loading : UiState()\n  data class Success(val items: List<Item>) : UiState()\n  data class Error(val msg: String) : UiState()\n}\n\nwhen (state) {\n  Loading -> showSpinner()\n  is Success -> render(state.items)\n  is Error -> toast(state.msg)\n}",
      "watchOut": "case 추가하면 when 분기 전부 컴파일 에러로 막힘 — 일부러 노린 안전망. else로 도배하면 이 안전망이 사라짐. sealed interface(Kotlin 1.5+)가 더 유연해서 요즘은 더 자주 써요."
    },
    "teaching_hints_en": {
      "what": "An abstract class with subtypes restricted to the same module/package. Because the compiler knows all subclasses, when can be checked exhaustively.",
      "why": "Enums force every case to share the same shape; sealed lets each case carry different data. Perfect for UI states, API responses, and error branches.",
      "how": "sealed class UiState {\n  object Loading : UiState()\n  data class Success(val items: List<Item>) : UiState()\n  data class Error(val msg: String) : UiState()\n}\n\nwhen (state) {\n  Loading -> showSpinner()\n  is Success -> render(state.items)\n  is Error -> toast(state.msg)\n}",
      "watchOut": "Adding a case forces every when to fail compilation — that's the safety net. A blanket else throws it away. Since 1.5, sealed interface is more flexible and increasingly preferred."
    },
    "analogies_ko": [
      "배달 앱 주문 상태 — '접수/조리중/배달중/완료' 외 상태는 정의된 적 없음. 새 상태가 생기면 화면 코드 다 점검해야 한다는 게 sealed의 약속."
    ],
    "analogies_en": [
      "A delivery app's order status — only the defined stages exist. Adding a new one forces every screen to acknowledge it; that's sealed's contract."
    ],
    "simpler_fallback": "kotlin-data-class"
  },
  {
    "id": "kotlin-coroutines-basics",
    "title_en": "Coroutines Basics",
    "title_ko": "코루틴 기초 (suspend, launch)",
    "level": "intermediate",
    "category": "Kotlin Advanced",
    "order": 10,
    "tip_ko": "suspend는 '잠깐 멈췄다 재개 가능한 함수' 표시. 호출하려면 다른 suspend 함수나 코루틴 빌더 안이어야 해요.",
    "tip_en": "suspend marks a function as pausable and resumable. Call it only from another suspend function or a coroutine builder.",
    "teaching_hints_ko": {
      "what": "스레드를 막지 않고 비동기 코드를 동기처럼 쓰게 해주는 경량 동시성 도구. suspend 함수는 멈췄다 재개되고, launch/async가 그 함수를 시작하는 빌더예요.",
      "why": "콜백 지옥(callback hell)과 Future.then().then() 체이닝을 없애고 위에서 아래로 읽히는 비동기 코드를 만들 수 있어요. 스레드보다 훨씬 가벼워서 수만 개 동시 실행도 가능.",
      "how": "suspend fun fetchUser(id: Long): User =\n  api.getUser(id)  // 네트워크 대기\n\nfun load(scope: CoroutineScope) {\n  scope.launch {\n    val u = fetchUser(1)  // 멈췄다 재개\n    println(u.name)\n  }\n}",
      "watchOut": "suspend 함수는 일반 함수에서 호출 못 해요 — 컴파일 에러. main에서 시작하려면 runBlocking, UI에선 viewModelScope/lifecycleScope. Thread.sleep 쓰지 마세요, delay() 쓰셔야 코루틴이 진짜로 양보해요."
    },
    "teaching_hints_en": {
      "what": "Lightweight concurrency that lets you write async code that reads sequentially. suspend functions can pause and resume; launch/async are builders that start them.",
      "why": "Eliminates callback hell and .then().then() chains, producing top-to-bottom readable async code. Far cheaper than threads — tens of thousands can run at once.",
      "how": "suspend fun fetchUser(id: Long): User =\n  api.getUser(id)  // awaits network\n\nfun load(scope: CoroutineScope) {\n  scope.launch {\n    val u = fetchUser(1)  // pauses, resumes\n    println(u.name)\n  }\n}",
      "watchOut": "You can't call suspend from a regular function — it's a compile error. Bootstrap from main with runBlocking, in UI use viewModelScope/lifecycleScope. Never Thread.sleep — use delay() so the coroutine actually yields."
    },
    "analogies_ko": [
      "식당 주문 — 종업원이 한 테이블 음식 기다리며 서있지 않고 다른 테이블 받으러 감. suspend는 '잠깐 자리 비웁니다' 신호, 음식 나오면 다시 와서 이어 처리."
    ],
    "analogies_en": [
      "A waiter taking orders — instead of standing at one table waiting for the kitchen, they take other orders and return when food is ready. suspend is the 'I'll be back' signal."
    ],
    "simpler_fallback": null
  },
  {
    "id": "kotlin-flow-basics",
    "title_en": "Flow Basics",
    "title_ko": "Flow 기초",
    "level": "intermediate",
    "category": "Kotlin Advanced",
    "order": 11,
    "tip_ko": "Flow는 '여러 값을 시간차로 흘려보내는 suspend 시퀀스'. collect 호출 전엔 아무 일도 안 일어나요 (cold).",
    "tip_en": "Flow is a suspending sequence of values over time. Nothing runs until you collect — it's cold.",
    "teaching_hints_ko": {
      "what": "코루틴 위에서 동작하는 비동기 스트림. 한 번 결과를 주는 suspend 함수와 달리, 여러 값을 시간차로 emit해요.",
      "why": "DB 변경, 위치 업데이트, 검색어 입력 같은 '계속 흘러오는 데이터'를 표현하기 좋아요. RxJava의 무거운 의존성 없이 표준 라이브러리로 가능.",
      "how": "fun ticker(): Flow<Int> = flow {\n  for (i in 1..5) {\n    delay(1000)\n    emit(i)\n  }\n}\n\nscope.launch {\n  ticker().collect { println(it) }\n}",
      "watchOut": "Flow는 cold라 collect 두 번 하면 블록이 두 번 실행돼요. 공유하려면 SharedFlow/StateFlow. UI에선 collect를 lifecycleScope에서 그냥 돌리지 말고 repeatOnLifecycle로 감싸야 백그라운드 누수 안 나요."
    },
    "teaching_hints_en": {
      "what": "An async stream built on coroutines. Unlike a suspend function that returns once, a Flow emits multiple values over time.",
      "why": "Models continuously changing data — DB updates, location, search input — without a heavy dep like RxJava. Pure standard library.",
      "how": "fun ticker(): Flow<Int> = flow {\n  for (i in 1..5) {\n    delay(1000)\n    emit(i)\n  }\n}\n\nscope.launch {\n  ticker().collect { println(it) }\n}",
      "watchOut": "Flows are cold — collecting twice runs the block twice. Use SharedFlow/StateFlow to share. In UI, don't naively collect inside lifecycleScope; wrap with repeatOnLifecycle to avoid background leaks."
    },
    "analogies_ko": [
      "수도꼭지 — 잠가두면 물 안 나옴(cold). 컵을 대야(collect) 그제야 흐름. SharedFlow는 분수대처럼 여러 사람이 같이 마시는 구조."
    ],
    "analogies_en": [
      "A faucet — closed, no water (cold). Place a cup (collect) and it flows. SharedFlow is a public fountain that many people drink from together."
    ],
    "simpler_fallback": "kotlin-coroutines-basics"
  },
  {
    "id": "kotlin-structured-concurrency",
    "title_en": "Structured Concurrency",
    "title_ko": "구조적 동시성 (CoroutineScope)",
    "level": "advanced",
    "category": "Kotlin Advanced",
    "order": 12,
    "tip_ko": "모든 코루틴은 부모 scope에 묶임. 부모가 취소되면 자식도 자동 취소 — 누수 걱정 끝.",
    "tip_en": "Every coroutine has a parent scope. Cancel the parent and children cancel too — no leaks.",
    "teaching_hints_ko": {
      "what": "코루틴이 항상 어떤 scope의 자식으로 시작되어, 부모-자식 관계로 생명주기가 묶이는 원칙. coroutineScope { }, supervisorScope { } 빌더가 핵심.",
      "why": "스레드 시절엔 시작한 작업을 안 닫으면 누수가 났어요. 구조적 동시성은 'scope 끝나기 전엔 자식이 다 끝난다'를 보장해서 누수 자체를 막아요.",
      "how": "suspend fun loadAll() = coroutineScope {\n  val a = async { fetchA() }\n  val b = async { fetchB() }\n  a.await() to b.await()\n}\n// 둘 중 하나 실패하면 다른 쪽도 자동 취소",
      "watchOut": "GlobalScope.launch { ... } 쓰면 이 안전망이 다 풀려요 — 거의 모든 경우 안티패턴. 한 자식만 실패하고 다른 자식은 살리고 싶다면 coroutineScope 대신 supervisorScope. ViewModel에선 viewModelScope를 쓰셔야 onCleared 시점에 자동 취소돼요."
    },
    "teaching_hints_en": {
      "what": "The principle that every coroutine launches as a child of some scope, tying its lifecycle to the parent. coroutineScope { } and supervisorScope { } are the key builders.",
      "why": "Raw threads leaked when you forgot to clean up. Structured concurrency guarantees children finish before the scope returns, eliminating leaks by construction.",
      "how": "suspend fun loadAll() = coroutineScope {\n  val a = async { fetchA() }\n  val b = async { fetchB() }\n  a.await() to b.await()\n}\n// If one fails, the other auto-cancels",
      "watchOut": "GlobalScope.launch { ... } discards the safety net — almost always an antipattern. If you want one child's failure not to kill siblings, use supervisorScope. In ViewModels, use viewModelScope so it cancels on onCleared."
    },
    "analogies_ko": [
      "회사 팀장과 팀원 — 팀이 해체되면 진행 중이던 팀원 작업도 정리. 누가 외부 프리랜서(GlobalScope)로 빼돌리면 회사 끝나도 그 일은 떠다님."
    ],
    "analogies_en": [
      "A team manager and reports — disband the team and in-flight work wraps up. Outsourcing to a GlobalScope freelancer means the work keeps going after the company shuts down."
    ],
    "simpler_fallback": "kotlin-coroutines-basics"
  },
  {
    "id": "kotlin-coroutine-context",
    "title_en": "Coroutine Context",
    "title_ko": "CoroutineContext (Dispatchers, Job)",
    "level": "advanced",
    "category": "Kotlin Advanced",
    "order": 13,
    "tip_ko": "Dispatchers는 '어느 스레드에서 돌릴지', Job은 '취소 핸들'. 둘이 합쳐진 게 CoroutineContext.",
    "tip_en": "Dispatchers decide which thread runs the work; Job is the cancel handle. Together they form a CoroutineContext.",
    "teaching_hints_ko": {
      "what": "코루틴 실행 환경을 담는 키-값 컬렉션. 핵심은 Dispatcher(어느 스레드 풀)와 Job(취소·완료 추적). + 연산자로 조합해요.",
      "why": "UI 갱신은 Main, IO는 Dispatchers.IO, CPU 무거운 건 Default — 명시적으로 분리해야 ANR이나 데드락이 안 나요. Job을 들고 있으면 외부에서 취소도 가능.",
      "how": "scope.launch(Dispatchers.IO) {\n  val data = fetchFromDb()\n  withContext(Dispatchers.Main) {\n    textView.text = data\n  }\n}\n// IO에서 작업, Main에서 UI 갱신",
      "watchOut": "Dispatchers.Main을 안드로이드 외 환경(테스트 등)에서 쓰면 죽어요 — kotlinx-coroutines-test의 StandardTestDispatcher 쓰셔야 해요. withContext는 블록 끝나면 원래 디스패처로 복귀, launch는 안 돌아옴. Dispatchers.IO에서 CPU 무거운 일 돌리지 마세요 (스레드 64개로 제한)."
    },
    "teaching_hints_en": {
      "what": "A key-value collection holding the coroutine's runtime environment. The big two: Dispatcher (which thread pool) and Job (tracks cancel/completion). Combine with the + operator.",
      "why": "UI work belongs on Main, IO on Dispatchers.IO, CPU-heavy on Default. Splitting them explicitly prevents ANRs and deadlocks. Holding the Job lets you cancel externally.",
      "how": "scope.launch(Dispatchers.IO) {\n  val data = fetchFromDb()\n  withContext(Dispatchers.Main) {\n    textView.text = data\n  }\n}\n// Work on IO, update UI on Main",
      "watchOut": "Dispatchers.Main crashes outside Android (e.g., tests) — use StandardTestDispatcher from kotlinx-coroutines-test. withContext returns to the original dispatcher when its block ends; launch does not. Don't run CPU-bound work on Dispatchers.IO — it caps at 64 threads."
    },
    "analogies_ko": [
      "우편물 분류 — Main은 카운터(고객 응대), IO는 창고(택배 정리), Default는 작업장(포장기계). 일 종류에 맞는 곳에 보내야 다른 일이 안 막혀요."
    ],
    "analogies_en": [
      "A post office — Main is the counter (customers), IO is the storeroom (parcels), Default is the workshop (heavy machines). Route work to the right room or everything jams."
    ],
    "simpler_fallback": "kotlin-coroutines-basics"
  },
  {
    "id": "kotlin-exception-coroutines",
    "title_en": "Exception Handling in Coroutines",
    "title_ko": "코루틴 예외 처리 (CoroutineExceptionHandler)",
    "level": "advanced",
    "category": "Kotlin Advanced",
    "order": 14,
    "tip_ko": "launch는 예외를 부모로 전파, async는 await에서 던짐. CancellationException은 절대 삼키지 마세요.",
    "tip_en": "launch propagates to the parent; async throws on await. Never swallow CancellationException.",
    "teaching_hints_ko": {
      "what": "코루틴에서 발생한 예외가 어떻게 흐르는지에 대한 규약. 빌더(launch/async), scope 종류(coroutineScope/supervisorScope), Handler가 결합해 동작해요.",
      "why": "동기 try/catch만으론 부모-자식 구조에서 형제 코루틴이 같이 죽거나, 예외가 통째로 사라지는 일이 생겨요. 규칙 알면 디버깅 시간이 시간 단위로 줄어요.",
      "how": "val handler = CoroutineExceptionHandler { _, e ->\n  log(\"caught $e\")\n}\nval scope = CoroutineScope(SupervisorJob() + handler)\nscope.launch {\n  throw IllegalStateException(\"boom\")\n  // handler가 잡음, 형제 코루틴은 살아있음\n}",
      "watchOut": "CoroutineExceptionHandler는 launch에만 동작 — async는 await 호출 지점에서 try/catch 해야 해요. try/catch (CancellationException)으로 잡고 그냥 넘기면 취소가 작동 안 해서 작업이 멈추질 않아요. supervisorScope 안에서만 형제가 안 죽고, 일반 coroutineScope는 한 명 죽으면 전부 취소."
    },
    "teaching_hints_en": {
      "what": "The contract for how exceptions flow through coroutines. The behavior depends on the builder (launch/async), the scope (coroutineScope/supervisorScope), and any installed handler.",
      "why": "Plain try/catch breaks down in parent-child trees: siblings die unexpectedly, or exceptions vanish silently. Knowing the rules saves hours of debugging.",
      "how": "val handler = CoroutineExceptionHandler { _, e ->\n  log(\"caught $e\")\n}\nval scope = CoroutineScope(SupervisorJob() + handler)\nscope.launch {\n  throw IllegalStateException(\"boom\")\n  // handler catches it; siblings keep running\n}",
      "watchOut": "CoroutineExceptionHandler only handles launch — for async you must try/catch around await. Catching CancellationException and ignoring it breaks cancellation propagation; rethrow it. Only supervisorScope keeps siblings alive — a normal coroutineScope cancels everyone if one fails."
    },
    "analogies_ko": [
      "병원 응급실 — 한 환자(자식 코루틴)가 위급해지면 일반 진료실(coroutineScope)은 전체 비상, 응급 전담실(supervisorScope)은 그 환자만 처치. 비상 알람(handler)은 launch 환자만 듣고 async 환자는 직접 깨워야(await) 들려요."
    ],
    "analogies_en": [
      "An ER — when one patient (child coroutine) crashes, a regular ward (coroutineScope) goes into full alert, but a triage suite (supervisorScope) handles just that one. The alarm (handler) only fires for launch patients; async patients only speak when you ask them (await)."
    ],
    "simpler_fallback": "kotlin-coroutines-basics"
  },
  {
    "id": "spring-ioc-di",
    "title_en": "IoC and Dependency Injection",
    "title_ko": "IoC와 의존성 주입 (DI)",
    "level": "beginner",
    "category": "Spring Core",
    "order": 15,
    "tip_ko": "객체를 직접 new 하지 말고 Spring한테 받으세요. 생성자 주입이 정답입니다.",
    "tip_en": "Don't `new` your dependencies — let Spring hand them to you. Constructor injection is the right default.",
    "teaching_hints_ko": {
      "what": "객체가 자기 의존성을 직접 만들지 않고, Spring 컨테이너가 만들어서 넣어주는 패턴. IoC(제어의 역전)의 가장 흔한 구현이 DI(의존성 주입)입니다.",
      "why": "코드끼리 강하게 묶이지 않아 테스트하기 쉽고 갈아끼우기 쉬워요. UserService가 어떤 Repository를 쓸지 직접 정하지 않고, 생성자에서 받기만 하면 됩니다.",
      "how": "@Service\nclass UserService(\n    private val repo: UserRepository\n) {\n    fun find(id: Long) = repo.findById(id)\n}\n// Spring이 UserRepository 빈을 찾아 자동 주입",
      "watchOut": "@Autowired field injection은 피하세요 — 테스트에서 mock 주입이 어렵고, 의존성이 숨어 보입니다. 생성자 주입은 컴파일 타임에 빠진 의존성을 잡아줘요."
    },
    "teaching_hints_en": {
      "what": "An object doesn't construct its own dependencies; the Spring container builds them and hands them in. DI is the most common form of IoC (Inversion of Control).",
      "why": "Loose coupling makes code testable and swappable. UserService doesn't decide which Repository to use — it just declares what it needs in the constructor.",
      "how": "@Service\nclass UserService(\n    private val repo: UserRepository\n) {\n    fun find(id: Long) = repo.findById(id)\n}\n// Spring finds the UserRepository bean and injects it",
      "watchOut": "Avoid @Autowired field injection — it hides dependencies and makes mocking painful in tests. Constructor injection surfaces missing dependencies at compile time."
    },
    "analogies_ko": [
      "식당 주방장이 매번 시장 가서 재료 사는 게 아니라, 납품 업체가 매일 아침 문 앞에 두고 가는 것. 주방장은 요리에만 집중.",
      "회사 신입은 책상/노트북을 직접 사지 않아요. 입사하면 이미 자리에 놓여 있죠 — Spring이 총무팀입니다."
    ],
    "analogies_en": [
      "A chef doesn't go to the market each morning — suppliers drop ingredients at the door so the chef can focus on cooking.",
      "A new hire doesn't buy their own laptop. It's on the desk on day one — Spring is the IT department."
    ],
    "simpler_fallback": null
  },
  {
    "id": "spring-component-scanning",
    "title_en": "Component Scanning",
    "title_ko": "컴포넌트 스캔 (@Component)",
    "level": "beginner",
    "category": "Spring Core",
    "order": 16,
    "tip_ko": "@Component(또는 @Service/@Repository/@Controller)를 붙이면 Spring이 자동으로 빈으로 등록해줘요.",
    "tip_en": "Annotate a class with @Component (or @Service/@Repository/@Controller) and Spring auto-registers it as a bean.",
    "teaching_hints_ko": {
      "what": "지정된 패키지 아래를 스캔해서 @Component 계열 어노테이션이 붙은 클래스를 자동으로 빈으로 만들어 컨테이너에 등록하는 기능.",
      "why": "수십 개 빈을 일일이 @Bean으로 선언하지 않아도 돼요. @SpringBootApplication이 기본 패키지부터 자동 스캔하니까 클래스만 적절히 어노테이션 붙이면 끝.",
      "how": "@Service\nclass OrderService(private val repo: OrderRepository)\n\n@Repository\nclass OrderRepository\n\n@SpringBootApplication\nclass App  // 같은 패키지 하위 자동 스캔",
      "watchOut": "@SpringBootApplication 클래스보다 위쪽 패키지에 둔 @Component는 스캔되지 않아요. 패키지 구조를 main 클래스 하위에 두거나 @ComponentScan(basePackages=\"...\")으로 명시 필요."
    },
    "teaching_hints_en": {
      "what": "Spring scans the configured packages and automatically registers classes carrying @Component-family annotations as beans.",
      "why": "You skip declaring dozens of @Bean methods. @SpringBootApplication scans from its package downward, so the right annotation on the class is enough.",
      "how": "@Service\nclass OrderService(private val repo: OrderRepository)\n\n@Repository\nclass OrderRepository\n\n@SpringBootApplication\nclass App  // scans below this package",
      "watchOut": "Components in packages above the @SpringBootApplication class aren't scanned. Keep your packages under the main class, or set @ComponentScan(basePackages = \"...\") explicitly."
    },
    "analogies_ko": [
      "회사가 새 직원 채용 공고를 패키지별로 돌리는 것 — '@Service 명찰' 단 사람만 자동으로 인사 시스템에 등록.",
      "도서관에서 ISBN이 박힌 책만 자동 분류기에 흘려보내는 것."
    ],
    "analogies_en": [
      "A company auto-rosters anyone wearing a '@Service' badge as they walk through the door.",
      "A library's auto-sorter only picks up books that have an ISBN sticker."
    ],
    "simpler_fallback": "spring-ioc-di"
  },
  {
    "id": "spring-bean-lifecycle",
    "title_en": "Bean Lifecycle",
    "title_ko": "빈 라이프사이클",
    "level": "basic",
    "category": "Spring Core",
    "order": 17,
    "tip_ko": "초기화는 @PostConstruct, 정리는 @PreDestroy. 생성자에서 무거운 작업하지 마세요.",
    "tip_en": "Initialize with @PostConstruct, clean up with @PreDestroy. Don't do heavy work in the constructor.",
    "teaching_hints_ko": {
      "what": "빈이 컨테이너 안에서 거치는 단계: 인스턴스 생성 → 의존성 주입 → 초기화 콜백(@PostConstruct) → 사용 → 소멸 콜백(@PreDestroy).",
      "why": "DB 커넥션 풀이나 캐시 워밍업처럼 의존성이 다 들어온 뒤 해야 하는 작업이 있어요. 생성자에서 하면 의존성이 아직 null일 수 있습니다.",
      "how": "@Service\nclass CacheLoader(private val repo: ConfigRepository) {\n    @PostConstruct\n    fun warmUp() { repo.findAll() }\n\n    @PreDestroy\n    fun flush() { /* 정리 */ }\n}",
      "watchOut": "생성자에서 외부 시스템 호출하면 빈 생성 자체가 실패해 앱이 안 뜸. 그리고 prototype 스코프 빈은 @PreDestroy가 호출되지 않아요 — 컨테이너가 추적 안 함."
    },
    "teaching_hints_en": {
      "what": "Stages a bean goes through inside the container: instantiate → inject dependencies → init callback (@PostConstruct) → use → destroy callback (@PreDestroy).",
      "why": "Work like cache warm-up or connection-pool setup needs all dependencies wired in first. Doing it in the constructor risks touching nulls.",
      "how": "@Service\nclass CacheLoader(private val repo: ConfigRepository) {\n    @PostConstruct\n    fun warmUp() { repo.findAll() }\n\n    @PreDestroy\n    fun flush() { /* cleanup */ }\n}",
      "watchOut": "Calling external systems from a constructor can prevent the app from starting. Also, @PreDestroy never fires on prototype-scoped beans — the container doesn't track them."
    },
    "analogies_ko": [
      "새 사무실 입주: 책상 들이고(생성), 인터넷 연결하고(주입), 기기 세팅(@PostConstruct), 일하다가, 퇴거 정리(@PreDestroy).",
      "비행기 탑승 절차 — 보딩, 체크, 이륙 준비, 운항, 착륙 정리."
    ],
    "analogies_en": [
      "Moving into an office: bring desks in (instantiate), hook up the network (inject), configure devices (@PostConstruct), work, clean up on move-out (@PreDestroy).",
      "An airplane: board, pre-flight check, taxi, fly, post-flight shutdown."
    ],
    "simpler_fallback": "spring-ioc-di"
  },
  {
    "id": "spring-bean-scope",
    "title_en": "Bean Scopes",
    "title_ko": "빈 스코프 (singleton, prototype, request)",
    "level": "basic",
    "category": "Spring Core",
    "order": 18,
    "tip_ko": "기본은 singleton. 매번 새 인스턴스가 필요할 때만 prototype을 고려하세요.",
    "tip_en": "Default to singleton. Reach for prototype only when you truly need a fresh instance every time.",
    "teaching_hints_ko": {
      "what": "빈이 컨테이너 안에서 몇 개 존재하는지를 결정. singleton은 앱 전체에 1개, prototype은 요청마다 새로, request/session은 웹 요청 단위.",
      "why": "stateless 서비스는 singleton이 메모리 효율적이고 안전해요. 사용자 세션 정보처럼 매 요청마다 다른 상태가 필요하면 request 스코프가 필요합니다.",
      "how": "@Service  // 기본 singleton\nclass UserService\n\n@Component\n@Scope(\"prototype\")\nclass ReportBuilder  // 주입받을 때마다 새 인스턴스",
      "watchOut": "singleton 빈에 mutable state(예: var counter)를 두면 멀티스레드에서 race condition 발생. 그리고 singleton 안에 prototype을 주입하면 한 번 주입된 그 인스턴스만 평생 씀 — Provider나 ObjectFactory로 해결."
    },
    "teaching_hints_en": {
      "what": "Defines how many instances of a bean live in the container. singleton = one per app, prototype = new every injection, request/session = per web request.",
      "why": "Stateless services should be singleton — memory-efficient and safe. Per-request data (like session state) needs a request-scoped bean.",
      "how": "@Service  // singleton by default\nclass UserService\n\n@Component\n@Scope(\"prototype\")\nclass ReportBuilder  // fresh instance per injection",
      "watchOut": "Mutable state in a singleton (e.g. var counter) is a race-condition magnet across threads. Also, injecting a prototype into a singleton freezes the instance — use a Provider or ObjectFactory for true freshness."
    },
    "analogies_ko": [
      "singleton은 회사 정수기 — 모두가 같은 거 씀. prototype은 종이컵 — 한 번 쓰고 버림. request 스코프는 손님 한 명에게 발급되는 번호표.",
      "singleton = 공유 차량, prototype = 일회용 택시, request = 단체 손님 한 명당 받는 영수증."
    ],
    "analogies_en": [
      "singleton = the office water cooler everyone shares. prototype = a paper cup, used once. request = a numbered ticket issued per visitor.",
      "singleton = shared car, prototype = a single-use cab, request = a receipt printed per customer visit."
    ],
    "simpler_fallback": "spring-bean-lifecycle"
  },
  {
    "id": "spring-configuration",
    "title_en": "@Configuration and @Bean",
    "title_ko": "@Configuration과 @Bean",
    "level": "basic",
    "category": "Spring Core",
    "order": 19,
    "tip_ko": "외부 라이브러리 객체나 조건부 빈은 @Configuration 클래스 안 @Bean 메서드로 등록하세요.",
    "tip_en": "Register third-party objects or conditional beans inside @Bean methods within an @Configuration class.",
    "teaching_hints_ko": {
      "what": "@Configuration 클래스는 빈 정의를 모은 설정 파일. 그 안의 @Bean 메서드 반환값이 컨테이너에 빈으로 등록돼요.",
      "why": "내가 만들지 않은 클래스(RestTemplate, ObjectMapper 같은 외부 라이브러리)에는 @Component를 붙일 수 없어요. @Bean으로 직접 만들어 등록합니다.",
      "how": "@Configuration\nclass AppConfig {\n    @Bean\n    fun restTemplate(): RestTemplate = RestTemplate()\n\n    @Bean\n    fun objectMapper(): ObjectMapper =\n        jacksonObjectMapper().findAndRegisterModules()\n}",
      "watchOut": "@Bean 메서드끼리 직접 호출해도 같은 빈이 재사용돼요(@Configuration의 CGLIB 프록시 덕분). 하지만 @Configuration 빼면 매번 새 객체 생성됩니다 — 헷갈리는 함정."
    },
    "teaching_hints_en": {
      "what": "An @Configuration class collects bean definitions. Each @Bean method's return value is registered as a bean in the container.",
      "why": "You can't slap @Component on classes you don't own (RestTemplate, ObjectMapper, etc.). @Bean lets you build and register them yourself.",
      "how": "@Configuration\nclass AppConfig {\n    @Bean\n    fun restTemplate(): RestTemplate = RestTemplate()\n\n    @Bean\n    fun objectMapper(): ObjectMapper =\n        jacksonObjectMapper().findAndRegisterModules()\n}",
      "watchOut": "Calling one @Bean method from another reuses the same bean (thanks to the CGLIB proxy on @Configuration). Drop the @Configuration and you get a brand-new instance every call — a subtle gotcha."
    },
    "analogies_ko": [
      "수입 가구 조립 매뉴얼 — 부품(외부 라이브러리)을 어떻게 조립할지 회사가 직접 정의해두는 문서.",
      "주방의 레시피 카드 — '이 재료(외부 클래스)로 이렇게 조리해서 빈으로 내놓아라'."
    ],
    "analogies_en": [
      "An assembly manual for imported furniture — your company writes down exactly how to put third-party parts together.",
      "A kitchen recipe card — 'take these ingredients (external classes) and serve them as a bean'."
    ],
    "simpler_fallback": "spring-component-scanning"
  },
  {
    "id": "spring-profiles",
    "title_en": "Spring Profiles",
    "title_ko": "Spring Profiles",
    "level": "intermediate",
    "category": "Spring Core",
    "order": 20,
    "tip_ko": "환경별 빈/설정은 @Profile로 분리하세요. 운영 DB가 dev에서 뜨는 사고를 막아줘요.",
    "tip_en": "Split environment-specific beans and config with @Profile — it prevents production DB credentials from booting in dev.",
    "teaching_hints_ko": {
      "what": "활성화된 프로파일 이름(dev, prod, test 등)에 따라 다른 빈/설정이 로드되는 메커니즘. application-{profile}.yml도 자동 매칭됩니다.",
      "why": "dev에서는 in-memory DB, prod에서는 RDS — 같은 코드로 환경별로 다르게 동작해야 할 때. 빌드 분기 없이 런타임 옵션 하나로 전환됩니다.",
      "how": "@Configuration\n@Profile(\"prod\")\nclass ProdMailConfig {\n    @Bean fun mailer(): Mailer = SesMailer()\n}\n\n@Configuration\n@Profile(\"!prod\")\nclass DevMailConfig {\n    @Bean fun mailer(): Mailer = ConsoleMailer()\n}",
      "watchOut": "활성 프로파일을 까먹으면 default가 떠서 진짜 사고남. SPRING_PROFILES_ACTIVE 환경변수를 CI/배포 파이프라인에서 명시적으로 박아두세요. 그리고 @Profile은 빈 단위 — 메서드가 아닌 클래스에 보통 붙입니다."
    },
    "teaching_hints_en": {
      "what": "Loads different beans and configs based on active profile names (dev, prod, test, …). application-{profile}.yml is matched automatically.",
      "why": "In-memory DB in dev, RDS in prod — same codebase, different runtime behavior. One flag flips the environment, no build branching.",
      "how": "@Configuration\n@Profile(\"prod\")\nclass ProdMailConfig {\n    @Bean fun mailer(): Mailer = SesMailer()\n}\n\n@Configuration\n@Profile(\"!prod\")\nclass DevMailConfig {\n    @Bean fun mailer(): Mailer = ConsoleMailer()\n}",
      "watchOut": "Forget to set the active profile and the default boots — real outages happen this way. Pin SPRING_PROFILES_ACTIVE explicitly in CI and deploy. @Profile usually goes on the class, not the method."
    },
    "analogies_ko": [
      "연극의 무대 세트 전환 — 같은 배우(코드)가 무대 배경(설정)만 바꿔서 다른 공연을 함.",
      "여행용 멀티 어댑터 — 한국/유럽/미국 콘센트에 맞춰 핀이 바뀜. 회로(앱)는 그대로."
    ],
    "analogies_en": [
      "Stage set changes in theater — the same actors (code) perform against a different backdrop (config) per show.",
      "A travel power adapter — the prongs swap for KR/EU/US sockets, the device underneath is the same."
    ],
    "simpler_fallback": "spring-configuration"
  },
  {
    "id": "spring-aop-basics",
    "title_en": "AOP Basics",
    "title_ko": "AOP 기초 (@Aspect, @Around)",
    "level": "intermediate",
    "category": "Spring Core",
    "order": 21,
    "tip_ko": "로깅, 트랜잭션, 권한 체크처럼 여기저기 흩뿌려진 관심사는 Aspect로 한 곳에 모으세요.",
    "tip_en": "Cross-cutting concerns like logging, transactions, and auth checks belong in one Aspect — not copy-pasted everywhere.",
    "teaching_hints_ko": {
      "what": "Aspect-Oriented Programming. 비즈니스 코드에 섞이는 부가 기능(로깅 등)을 별도 객체(Aspect)로 분리하고, Spring이 프록시로 끼워 넣어 실행시켜요.",
      "why": "100개 메서드에 똑같은 로그/측정 코드를 복붙하지 않아도 됨. @Transactional도 사실 AOP — 어노테이션 하나로 트랜잭션이 알아서 열고 닫혀요.",
      "how": "@Aspect\n@Component\nclass TimingAspect {\n    @Around(\"execution(* com.app.service..*(..))\")\n    fun measure(pjp: ProceedingJoinPoint): Any? {\n        val start = System.currentTimeMillis()\n        return pjp.proceed().also {\n            log.info(\"${'$'}{pjp.signature.name} took ${'$'}{System.currentTimeMillis() - start}ms\")\n        }\n    }\n}",
      "watchOut": "AOP는 Spring 빈을 통해 호출될 때만 작동. 같은 클래스 안에서 this.method() 호출하면 프록시를 안 거쳐 Aspect가 적용 안 됩니다 — 자기 자신 호출(self-invocation) 함정."
    },
    "teaching_hints_en": {
      "what": "Aspect-Oriented Programming. Pull cross-cutting code (logging, etc.) out of your business logic into an Aspect; Spring weaves it in via proxies.",
      "why": "Stop copy-pasting timing or logging into 100 methods. Even @Transactional is AOP under the hood — one annotation, automatic begin/commit.",
      "how": "@Aspect\n@Component\nclass TimingAspect {\n    @Around(\"execution(* com.app.service..*(..))\")\n    fun measure(pjp: ProceedingJoinPoint): Any? {\n        val start = System.currentTimeMillis()\n        return pjp.proceed().also {\n            log.info(\"${'$'}{pjp.signature.name} took ${'$'}{System.currentTimeMillis() - start}ms\")\n        }\n    }\n}",
      "watchOut": "AOP only triggers when calls go through a Spring-managed bean. Calling this.method() inside the same class bypasses the proxy — the classic self-invocation trap."
    },
    "analogies_ko": [
      "회사 출입구의 보안 게이트 — 모든 직원이 출입할 때 자동으로 카드 찍힘. 직원이 일일이 '나 출입하는 중' 신고 안 함.",
      "공항 보안검색 — 비행기(비즈니스 로직) 타기 전에 공통 절차(Aspect)가 자동 적용."
    ],
    "analogies_en": [
      "A security gate at the office entrance — every employee badges in automatically, nobody has to announce their entry.",
      "Airport security — a shared procedure (Aspect) runs before everyone boards, regardless of which flight (method)."
    ],
    "simpler_fallback": "spring-bean-lifecycle"
  },
  {
    "id": "spring-rest-controller",
    "title_en": "REST Controllers and Mapping",
    "title_ko": "@RestController와 매핑",
    "level": "basic",
    "category": "Spring Web",
    "order": 22,
    "tip_ko": "JSON API는 @RestController. 클래스에 @RequestMapping(\"/api/users\") 붙여 prefix 통일하세요.",
    "tip_en": "Use @RestController for JSON APIs. Put a @RequestMapping(\"/api/users\") on the class to unify the path prefix.",
    "teaching_hints_ko": {
      "what": "@RestController = @Controller + @ResponseBody. 메서드 반환값이 자동으로 JSON으로 직렬화되어 응답 본문에 들어갑니다.",
      "why": "View 템플릿 렌더링 없이 JSON 응답이 필요한 REST API에서 표준. @GetMapping/@PostMapping 같은 메타 어노테이션이 코드를 깔끔하게 해줘요.",
      "how": "@RestController\n@RequestMapping(\"/api/users\")\nclass UserController(private val service: UserService) {\n    @GetMapping(\"/{id}\")\n    fun get(@PathVariable id: Long): User = service.find(id)\n\n    @PostMapping\n    fun create(@RequestBody req: CreateUserRequest): User = service.create(req)\n}",
      "watchOut": "@Controller만 붙이면 반환값을 view 이름으로 해석해 404 납니다 — REST API에는 무조건 @RestController. 그리고 매핑 충돌(같은 경로 두 메서드)은 시작 시 에러로 잡혀요."
    },
    "teaching_hints_en": {
      "what": "@RestController = @Controller + @ResponseBody. Method return values are auto-serialized to JSON in the response body.",
      "why": "Standard for REST APIs that return JSON instead of rendering view templates. Meta-annotations like @GetMapping/@PostMapping keep code clean.",
      "how": "@RestController\n@RequestMapping(\"/api/users\")\nclass UserController(private val service: UserService) {\n    @GetMapping(\"/{id}\")\n    fun get(@PathVariable id: Long): User = service.find(id)\n\n    @PostMapping\n    fun create(@RequestBody req: CreateUserRequest): User = service.create(req)\n}",
      "watchOut": "Plain @Controller treats the return value as a view name — you'll get 404s on a REST API. Always use @RestController for JSON. Path collisions surface at startup as errors."
    },
    "analogies_ko": [
      "호텔 프론트 데스크 — 손님(요청) 받으면 객실 키(JSON 응답) 바로 발급. 별도 식당으로 안내(view 렌더링) 안 함.",
      "드라이브스루 창구 — 차량 번호(@PathVariable) 확인하고 주문(JSON) 바로 반환."
    ],
    "analogies_en": [
      "A hotel front desk that hands you a room key (JSON) on the spot — no detour to the dining room (view rendering).",
      "A drive-through window — read the plate (@PathVariable), hand back the order (JSON)."
    ],
    "simpler_fallback": "spring-component-scanning"
  },
  {
    "id": "spring-request-response",
    "title_en": "Request and Response Objects",
    "title_ko": "Request/Response 객체",
    "level": "basic",
    "category": "Spring Web",
    "order": 23,
    "tip_ko": "요청 입력은 DTO data class로 받고, 응답도 DTO로 변환해서 보내세요. Entity 그대로 노출 X.",
    "tip_en": "Accept input as a data class DTO and return DTOs. Don't leak your JPA entities directly.",
    "teaching_hints_ko": {
      "what": "@RequestBody는 JSON 본문을 객체로 역직렬화, @PathVariable은 URL 경로 변수, @RequestParam은 쿼리 파라미터를 매핑. 응답은 ResponseEntity로 상태 코드까지 제어 가능.",
      "why": "Entity를 그대로 응답하면 DB 컬럼이 모두 노출되고, lazy 필드 로딩 사고가 납니다. DTO로 명시적 계약을 두면 API와 DB가 독립적으로 진화해요.",
      "how": "data class CreateUserRequest(val email: String, val name: String)\ndata class UserResponse(val id: Long, val name: String)\n\n@PostMapping\nfun create(@RequestBody req: CreateUserRequest): ResponseEntity<UserResponse> {\n    val user = service.create(req)\n    return ResponseEntity.status(201).body(UserResponse(user.id, user.name))\n}",
      "watchOut": "Entity 직접 반환은 순환 참조로 직렬화 무한 루프 또는 LazyInitializationException 유발. 그리고 @RequestParam의 required=true가 기본 — 누락되면 400, nullable로 받으려면 required=false 또는 Kotlin nullable 타입."
    },
    "teaching_hints_en": {
      "what": "@RequestBody deserializes the JSON body into an object; @PathVariable maps URL path segments; @RequestParam maps query strings. Use ResponseEntity to control status and headers.",
      "why": "Returning entities exposes every DB column and triggers lazy-loading errors. DTOs give you an explicit contract so API and DB can evolve independently.",
      "how": "data class CreateUserRequest(val email: String, val name: String)\ndata class UserResponse(val id: Long, val name: String)\n\n@PostMapping\nfun create(@RequestBody req: CreateUserRequest): ResponseEntity<UserResponse> {\n    val user = service.create(req)\n    return ResponseEntity.status(201).body(UserResponse(user.id, user.name))\n}",
      "watchOut": "Returning entities directly causes serializer infinite loops on bidirectional refs or LazyInitializationException. @RequestParam is required by default — missing values yield 400. Use required=false or a Kotlin nullable type for optional params."
    },
    "analogies_ko": [
      "식당 메뉴판(API DTO)과 주방 재료(DB Entity)는 별개여야 함. 손님한테 재료 그대로 갖다주면 안 되죠.",
      "택배 송장 — 발송 정보(요청)와 수령 확인(응답)이 정형화된 양식이라 처리가 빨라짐."
    ],
    "analogies_en": [
      "A restaurant menu (DTO) is not the raw pantry inventory (entity). You don't hand customers raw ingredients.",
      "A shipping label — standardized request/receipt forms make handling fast and unambiguous."
    ],
    "simpler_fallback": "spring-rest-controller"
  },
  {
    "id": "spring-validation",
    "title_en": "@Valid and Bean Validation",
    "title_ko": "@Valid와 Bean Validation",
    "level": "basic",
    "category": "Spring Web",
    "order": 24,
    "tip_ko": "DTO 필드에 @NotBlank, @Email, @Size를 박고 컨트롤러 파라미터에 @Valid를 붙이면 검증 끝.",
    "tip_en": "Annotate DTO fields with @NotBlank, @Email, @Size; add @Valid to the controller parameter — validation done.",
    "teaching_hints_ko": {
      "what": "Jakarta Bean Validation 표준 어노테이션으로 DTO 필드 제약을 선언하고, 컨트롤러 파라미터에 @Valid를 붙여 자동 검증.",
      "why": "if (email.isBlank()) ... 같은 검증 코드를 컨트롤러마다 반복할 필요 없어요. 위반 시 자동으로 MethodArgumentNotValidException 발생 → @ControllerAdvice로 깔끔하게 400 응답.",
      "how": "data class SignupRequest(\n    @field:NotBlank val name: String,\n    @field:Email val email: String,\n    @field:Size(min = 8) val password: String\n)\n\n@PostMapping(\"/signup\")\nfun signup(@Valid @RequestBody req: SignupRequest) { ... }",
      "watchOut": "Kotlin에서는 @field: 타깃을 꼭 붙이세요 — 안 붙이면 어노테이션이 생성자 파라미터에만 달려 검증이 안 먹습니다. 그리고 spring-boot-starter-validation 의존성 추가 안 하면 무시되고 통과돼요."
    },
    "teaching_hints_en": {
      "what": "Declare field constraints with Jakarta Bean Validation annotations on a DTO and add @Valid to the controller parameter — Spring validates automatically.",
      "why": "Stop repeating `if (email.isBlank())` in every controller. Violations throw MethodArgumentNotValidException, which @ControllerAdvice can map to a clean 400.",
      "how": "data class SignupRequest(\n    @field:NotBlank val name: String,\n    @field:Email val email: String,\n    @field:Size(min = 8) val password: String\n)\n\n@PostMapping(\"/signup\")\nfun signup(@Valid @RequestBody req: SignupRequest) { ... }",
      "watchOut": "In Kotlin you must use the @field: target — otherwise the annotation lands only on the constructor parameter and validation is silently skipped. Also, without spring-boot-starter-validation on the classpath, validation just doesn't run."
    },
    "analogies_ko": [
      "은행 신청서 — 빈칸 두면 창구에서 바로 반려. 직원이 매번 잔소리할 필요 없이 양식 자체가 검증함.",
      "공항 자동출입국 게이트 — 여권 칩이 조건 충족해야 통과, 안 되면 직원 부르기 전에 막힘."
    ],
    "analogies_en": [
      "A bank form that bounces back at the counter when fields are blank — the form validates itself; the teller doesn't have to.",
      "An e-gate at the airport — passport chip must satisfy constraints to pass; otherwise it bounces you before a human even sees it."
    ],
    "simpler_fallback": "spring-rest-controller"
  },
  {
    "id": "spring-exception-handler",
    "title_en": "Global Exception Handling",
    "title_ko": "@ControllerAdvice 예외 처리",
    "level": "intermediate",
    "category": "Spring Web",
    "order": 25,
    "tip_ko": "예외는 컨트롤러마다 try-catch 하지 말고 @RestControllerAdvice 한 곳에 모아 처리하세요.",
    "tip_en": "Don't try-catch in every controller. Centralize errors in one @RestControllerAdvice.",
    "teaching_hints_ko": {
      "what": "@RestControllerAdvice 클래스에 @ExceptionHandler 메서드를 모아 두면, 앱 전역에서 발생한 해당 예외를 가로채 통일된 JSON 에러 응답을 만들어줍니다.",
      "why": "에러 응답 포맷이 컨트롤러마다 제각각이면 클라이언트가 괴롭습니다. 한 곳에서 정의하면 status code, error code, message 형식이 항상 일관돼요.",
      "how": "@RestControllerAdvice\nclass GlobalExceptionHandler {\n    @ExceptionHandler(IllegalArgumentException::class)\n    fun handleBadRequest(e: IllegalArgumentException) =\n        ResponseEntity.badRequest().body(ErrorResponse(\"BAD_REQUEST\", e.message))\n\n    @ExceptionHandler(MethodArgumentNotValidException::class)\n    fun handleValidation(e: MethodArgumentNotValidException) =\n        ResponseEntity.badRequest().body(ErrorResponse(\"VALIDATION\", e.bindingResult.toMessage()))\n}",
      "watchOut": "예외를 너무 광범위(Exception::class)하게 잡으면 진짜 버그가 200 OK로 묻혀요. 구체적인 예외부터 잡고 마지막에 fallback 두기. 그리고 핸들러 안에서 또 예외 던지면 기본 에러 페이지로 빠집니다."
    },
    "teaching_hints_en": {
      "what": "An @RestControllerAdvice class collects @ExceptionHandler methods that intercept exceptions across the app and return a uniform JSON error.",
      "why": "Inconsistent error shapes are painful for clients. Define them once and every endpoint emits the same status/code/message format.",
      "how": "@RestControllerAdvice\nclass GlobalExceptionHandler {\n    @ExceptionHandler(IllegalArgumentException::class)\n    fun handleBadRequest(e: IllegalArgumentException) =\n        ResponseEntity.badRequest().body(ErrorResponse(\"BAD_REQUEST\", e.message))\n\n    @ExceptionHandler(MethodArgumentNotValidException::class)\n    fun handleValidation(e: MethodArgumentNotValidException) =\n        ResponseEntity.badRequest().body(ErrorResponse(\"VALIDATION\", e.bindingResult.toMessage()))\n}",
      "watchOut": "Catching Exception::class too broadly hides real bugs behind 200 OK responses. Handle specific exceptions first, fallback last. If a handler throws, you fall through to the default error page."
    },
    "analogies_ko": [
      "고객센터 통합 창구 — 부서마다 따로 응대 안 하고, 한 곳에서 일관된 안내 양식으로 처리.",
      "병원 응급실 트리아지 — 어떤 증상이든 일단 한 데서 분류하고 표준 절차로 보냄."
    ],
    "analogies_en": [
      "A unified customer-support desk — every department's complaints route through one team using the same response template.",
      "ER triage — every symptom funnels through one intake desk that classifies and routes by a standard playbook."
    ],
    "simpler_fallback": "spring-rest-controller"
  },
  {
    "id": "spring-filters-interceptors",
    "title_en": "Filters and Interceptors",
    "title_ko": "필터와 인터셉터",
    "level": "intermediate",
    "category": "Spring Web",
    "order": 26,
    "tip_ko": "Servlet 레벨은 Filter, Spring MVC 컨텍스트가 필요하면 HandlerInterceptor. 둘은 다른 계층입니다.",
    "tip_en": "Filter operates at the Servlet layer; HandlerInterceptor sits inside Spring MVC. Different layers, different powers.",
    "teaching_hints_ko": {
      "what": "Filter는 Servlet 표준 — 모든 요청/응답 앞뒤에서 실행. Interceptor는 Spring MVC 전용 — 컨트롤러 진입 직전/직후에 끼어듦. 핸들러 정보 같은 Spring 컨텍스트는 Interceptor에서만 접근 가능.",
      "why": "공통 로깅/인증/MDC 설정 등을 한 곳에서 처리하기 위해. Filter가 더 바깥, Interceptor가 더 안쪽 — 필요한 정보 깊이에 따라 골라요.",
      "how": "@Component\nclass AuthInterceptor : HandlerInterceptor {\n    override fun preHandle(req: HttpServletRequest, res: HttpServletResponse, h: Any): Boolean {\n        val token = req.getHeader(\"Authorization\") ?: return false.also { res.status = 401 }\n        return true\n    }\n}\n\n@Configuration\nclass WebConfig(private val auth: AuthInterceptor) : WebMvcConfigurer {\n    override fun addInterceptors(r: InterceptorRegistry) { r.addInterceptor(auth) }\n}",
      "watchOut": "Filter는 정적 리소스 요청까지 다 거치니까 무거운 로직 넣으면 성능 영향 큼. Interceptor의 preHandle에서 false 반환하면 컨트롤러 호출 자체를 막는데, 응답을 직접 써주지 않으면 빈 응답이 나갑니다."
    },
    "teaching_hints_en": {
      "what": "Filter is Servlet-standard — wraps every request/response. HandlerInterceptor is Spring MVC-specific — runs right before/after the controller. Only Interceptor sees Spring's handler metadata.",
      "why": "One place for logging, auth, MDC setup, etc. Filter is the outer ring; Interceptor is the inner ring. Pick by how much Spring context you need.",
      "how": "@Component\nclass AuthInterceptor : HandlerInterceptor {\n    override fun preHandle(req: HttpServletRequest, res: HttpServletResponse, h: Any): Boolean {\n        val token = req.getHeader(\"Authorization\") ?: return false.also { res.status = 401 }\n        return true\n    }\n}\n\n@Configuration\nclass WebConfig(private val auth: AuthInterceptor) : WebMvcConfigurer {\n    override fun addInterceptors(r: InterceptorRegistry) { r.addInterceptor(auth) }\n}",
      "watchOut": "Filter touches static resources too — heavy logic kills latency. Returning false from preHandle blocks the controller, but if you don't write the response yourself, the client gets an empty body."
    },
    "analogies_ko": [
      "회사 건물 1층 보안(Filter)과 회의실 입구 카드 리더(Interceptor) — 둘 다 통과 의식이지만 위치가 다름.",
      "공항 입국심사(Filter)는 모든 승객, 환승 보안(Interceptor)은 특정 게이트 가는 사람만."
    ],
    "analogies_en": [
      "Lobby security (Filter) vs. the meeting-room badge reader (Interceptor) — both are checkpoints, at different depths.",
      "Airport immigration (Filter) checks everyone; gate security (Interceptor) only screens people heading to a specific flight."
    ],
    "simpler_fallback": "spring-rest-controller"
  },
  {
    "id": "spring-async-controllers",
    "title_en": "Async Controllers",
    "title_ko": "비동기 컨트롤러",
    "level": "advanced",
    "category": "Spring Web",
    "order": 27,
    "tip_ko": "Spring MVC에서도 컨트롤러를 suspend fun으로 만들면 코루틴 기반 비동기 처리가 됩니다.",
    "tip_en": "Even on Spring MVC, declaring a controller as a suspend fun runs it asynchronously on coroutines.",
    "teaching_hints_ko": {
      "what": "컨트롤러 메서드를 suspend fun으로 선언하거나 CompletableFuture/Mono를 반환하면, Spring이 응답을 비동기로 처리해 서블릿 스레드를 즉시 풀어줍니다.",
      "why": "외부 API/DB 호출이 길면 동기 컨트롤러는 그 시간 동안 톰캣 스레드를 점유해요. 비동기로 돌리면 적은 스레드로 더 많은 동시 요청을 처리할 수 있습니다.",
      "how": "@RestController\nclass FeedController(private val client: ExternalClient) {\n    @GetMapping(\"/feed\")\n    suspend fun feed(): FeedResponse = coroutineScope {\n        val posts = async { client.fetchPosts() }\n        val ads = async { client.fetchAds() }\n        FeedResponse(posts.await(), ads.await())\n    }\n}",
      "watchOut": "suspend fun 안에서 blocking JDBC 호출하면 코루틴이 스레드를 잡아먹어 의미가 없어요 — withContext(Dispatchers.IO)로 격리. 그리고 @Transactional은 코루틴 컨텍스트와 잘 안 맞으니 트랜잭션은 별도 동기 서비스로 분리하는 게 안전."
    },
    "teaching_hints_en": {
      "what": "Declare a controller as a suspend fun or return CompletableFuture/Mono, and Spring releases the servlet thread while the response is computed asynchronously.",
      "why": "Slow external API/DB calls hog Tomcat threads in synchronous controllers. Async lets a small thread pool serve far more concurrent requests.",
      "how": "@RestController\nclass FeedController(private val client: ExternalClient) {\n    @GetMapping(\"/feed\")\n    suspend fun feed(): FeedResponse = coroutineScope {\n        val posts = async { client.fetchPosts() }\n        val ads = async { client.fetchAds() }\n        FeedResponse(posts.await(), ads.await())\n    }\n}",
      "watchOut": "Blocking JDBC inside a suspend fun pins the coroutine to a thread — wrap it in withContext(Dispatchers.IO). @Transactional doesn't compose cleanly with coroutines either; isolate transactions in a synchronous service layer."
    },
    "analogies_ko": [
      "식당 서버가 주문만 받고 바로 다른 손님 응대 — 주방(외부 호출)에서 음식 나오면 갖다 줌. 한 손님 끝날 때까지 옆에 서 있지 않음.",
      "콜센터에서 보류(Hold) 걸어두고 다른 전화 받기 — 회선 효율이 확 올라감."
    ],
    "analogies_en": [
      "A waiter takes the order and moves on — they come back when the kitchen rings the bell, instead of standing at the table the whole time.",
      "Call-center agents put a caller on hold to take another call — the same line-count handles more conversations."
    ],
    "simpler_fallback": "kotlin-coroutines-basics"
  },
  {
    "id": "spring-jpa-basics",
    "title_en": "JPA Basics",
    "title_ko": "JPA 기초 (@Entity, JpaRepository)",
    "level": "basic",
    "category": "Spring Data",
    "order": 28,
    "tip_ko": "테이블은 @Entity 클래스로, CRUD는 JpaRepository로. SQL 한 줄도 안 써도 기본 조회/저장이 돼요.",
    "tip_en": "Map tables with @Entity, get CRUD for free via JpaRepository. No SQL needed for basic operations.",
    "teaching_hints_ko": {
      "what": "JPA는 객체와 DB 테이블을 자동 매핑해주는 표준이에요. @Entity는 '이 클래스가 한 행', JpaRepository는 '저장/조회 메서드 자동 제공' 역할.",
      "why": "JDBC로 매번 SQL 짜고 ResultSet 파싱하는 보일러플레이트를 없애요. 비즈니스 로직에 집중할 수 있게 해줍니다.",
      "how": "@Entity\nclass User(\n  @Id @GeneratedValue val id: Long? = null,\n  val email: String\n)\n\ninterface UserRepository : JpaRepository<User, Long> {\n  fun findByEmail(email: String): User?\n}",
      "watchOut": "JPA Entity는 data class로 만들면 안 돼요. equals/hashCode가 프로퍼티 기준으로 만들어져 LAZY 프록시랑 충돌하고, 순환 참조에서 StackOverflow 터져요. 그냥 class로."
    },
    "teaching_hints_en": {
      "what": "JPA is the standard for mapping objects to database tables. @Entity marks a class as a row, JpaRepository auto-provides save/find methods.",
      "why": "Eliminates JDBC boilerplate — no more hand-written SQL or ResultSet parsing for basic CRUD. Lets you focus on business logic.",
      "how": "@Entity\nclass User(\n  @Id @GeneratedValue val id: Long? = null,\n  val email: String\n)\n\ninterface UserRepository : JpaRepository<User, Long> {\n  fun findByEmail(email: String): User?\n}",
      "watchOut": "Don't use data class for JPA entities. Generated equals/hashCode based on properties clashes with LAZY proxies and causes StackOverflow on bidirectional relations. Stick with plain class."
    },
    "analogies_ko": [
      "@Entity는 도서관 책 한 권, JpaRepository는 사서 — 책 번호만 알려주면 알아서 꺼내고 정리해줘요."
    ],
    "analogies_en": [
      "@Entity is a book in a library, JpaRepository is the librarian — give the call number and they fetch or shelve it for you."
    ],
    "simpler_fallback": "spring-component-scanning"
  },
  {
    "id": "spring-jpa-relationships",
    "title_en": "JPA Relationships",
    "title_ko": "JPA 연관관계 (@OneToMany, @ManyToMany)",
    "level": "basic",
    "category": "Spring Data",
    "order": 29,
    "tip_ko": "양방향 관계에선 연관관계 주인을 명확히 정하세요. mappedBy가 붙은 쪽은 읽기 전용이에요.",
    "tip_en": "In bidirectional relations, designate one owning side. The side with mappedBy is read-only for the foreign key.",
    "teaching_hints_ko": {
      "what": "Entity끼리 1:N, N:1, N:M 관계를 표현하는 어노테이션. @ManyToOne은 외래키 가진 쪽, @OneToMany는 반대편. mappedBy로 양방향 매핑.",
      "why": "DB의 JOIN 관계를 객체 그래프로 자연스럽게 다룰 수 있어요. user.posts 한 줄로 연관 데이터 조회.",
      "how": "@Entity class Post(\n  @Id @GeneratedValue val id: Long? = null,\n  @ManyToOne(fetch = LAZY) val author: User\n)\n\n@Entity class User(\n  @Id @GeneratedValue val id: Long? = null,\n  @OneToMany(mappedBy = \"author\") val posts: MutableList<Post> = mutableListOf()\n)",
      "watchOut": "@ManyToMany는 추가 컬럼 못 넣어요. 중간 테이블에 createdAt 같은 거 필요하면 @OneToMany 두 개 + 중간 Entity로 풀어야 해요. CascadeType.REMOVE도 양방향 모두에 걸면 무한 루프 날 수 있어요."
    },
    "teaching_hints_en": {
      "what": "Annotations express 1:N, N:1, N:M relationships between entities. @ManyToOne owns the foreign key, @OneToMany is the inverse. Use mappedBy for bidirectional mapping.",
      "why": "DB JOIN relationships become a natural object graph. user.posts gives you related data in one expression.",
      "how": "@Entity class Post(\n  @Id @GeneratedValue val id: Long? = null,\n  @ManyToOne(fetch = LAZY) val author: User\n)\n\n@Entity class User(\n  @Id @GeneratedValue val id: Long? = null,\n  @OneToMany(mappedBy = \"author\") val posts: MutableList<Post> = mutableListOf()\n)",
      "watchOut": "@ManyToMany can't carry extra columns. If you need createdAt on the join, model it as two @OneToMany + a join entity. Putting CascadeType.REMOVE on both sides of a bidirectional relation can also cause infinite loops."
    },
    "analogies_ko": [
      "사원증과 부서 배지처럼 — 사원증(외래키)은 한쪽이 주인이고, 반대편은 '우리 부서 사람들'이라고 참조만 해요."
    ],
    "analogies_en": [
      "Like an employee badge and a department roster — the badge (foreign key) belongs to the employee, the roster just references them."
    ],
    "simpler_fallback": "spring-jpa-basics"
  },
  {
    "id": "spring-jpa-fetch-strategies",
    "title_en": "Fetch Strategies and N+1",
    "title_ko": "Fetch 전략 (LAZY/EAGER, N+1)",
    "level": "intermediate",
    "category": "Spring Data",
    "order": 30,
    "tip_ko": "기본은 LAZY. 연관 데이터가 진짜 필요하면 fetch join이나 @EntityGraph로 한 번에 가져와요.",
    "tip_en": "Default to LAZY. When related data is actually needed, fetch it together via fetch join or @EntityGraph.",
    "teaching_hints_ko": {
      "what": "LAZY는 연관 Entity를 실제 접근할 때 쿼리, EAGER는 부모 조회 시 즉시 같이 쿼리. N+1은 부모 1번 쿼리 후 자식마다 N번 추가 쿼리 나가는 성능 함정.",
      "why": "EAGER 무지성 사용 시 안 쓰는 데이터까지 매번 로딩. LAZY는 효율적이지만 N+1 함정이 있어 fetch join으로 해결해야 해요.",
      "how": "// N+1 발생\nval users = userRepo.findAll()\nusers.forEach { println(it.posts.size) }  // user마다 쿼리\n\n// 해결: fetch join\n@Query(\"select u from User u join fetch u.posts\")\nfun findAllWithPosts(): List<User>",
      "watchOut": "LAZY 컬렉션을 트랜잭션 밖(예: Controller, View)에서 접근하면 LazyInitializationException 터져요. open-in-view는 임시방편이고, DTO로 변환해서 내보내거나 @EntityGraph 권장."
    },
    "teaching_hints_en": {
      "what": "LAZY queries related entities on access; EAGER queries them with the parent. N+1 is the trap where 1 parent query triggers N extra child queries.",
      "why": "Blind EAGER loads data you may never use. LAZY is efficient but exposes you to N+1 — solve it with fetch join.",
      "how": "// N+1 problem\nval users = userRepo.findAll()\nusers.forEach { println(it.posts.size) }  // 1 query per user\n\n// Fix: fetch join\n@Query(\"select u from User u join fetch u.posts\")\nfun findAllWithPosts(): List<User>",
      "watchOut": "Accessing a LAZY collection outside the transaction (Controller, View) throws LazyInitializationException. open-in-view is a band-aid — prefer DTO projection or @EntityGraph."
    },
    "analogies_ko": [
      "LAZY는 메뉴판 — 주문할 때 음식이 나옴. EAGER는 뷔페 — 식탁에 모두 깔아둠. N+1은 손님마다 주방에 따로 다녀오는 종업원."
    ],
    "analogies_en": [
      "LAZY is a menu — food arrives when you order. EAGER is a buffet — everything is on the table. N+1 is a waiter who runs to the kitchen separately for each guest."
    ],
    "simpler_fallback": "spring-jpa-relationships"
  },
  {
    "id": "spring-querydsl",
    "title_en": "QueryDSL Basics",
    "title_ko": "QueryDSL 기초",
    "level": "intermediate",
    "category": "Spring Data",
    "order": 31,
    "tip_ko": "동적 쿼리는 QueryDSL로. 문자열 JPQL과 달리 컴파일 타임에 오타가 잡혀요.",
    "tip_en": "Use QueryDSL for dynamic queries. Unlike string JPQL, typos are caught at compile time.",
    "teaching_hints_ko": {
      "what": "타입 안전한 쿼리 빌더 라이브러리. 컴파일러가 Q클래스(QUser 등)를 생성해주고, 메서드 체이닝으로 SQL을 만들어요.",
      "why": "검색 조건이 동적으로 바뀌는 화면(필터, 정렬)에서 if-else로 JPQL 문자열 짜는 지옥을 피해요. IDE 자동완성 + 리팩터링도 안전.",
      "how": "@Repository\nclass PostQueryRepository(private val query: JPAQueryFactory) {\n  fun search(keyword: String?): List<Post> {\n    val p = QPost.post\n    return query.selectFrom(p)\n      .where(keyword?.let { p.title.contains(it) })\n      .fetch()\n  }\n}",
      "watchOut": "Q클래스는 빌드 시 생성돼서 IDE에서 빨갛게 보일 수 있어요. annotationProcessor 설정 + 한 번 빌드하면 됨. where절에 null 넘기면 자동 무시되는 점 활용해 동적 조건 깔끔하게 짤 수 있어요."
    },
    "teaching_hints_en": {
      "what": "Type-safe query builder. The compiler generates Q-classes (QUser, etc.) and you build SQL via method chaining.",
      "why": "Avoids the if-else hell of building JPQL strings for screens with dynamic filters/sorts. IDE autocomplete and refactoring stay safe.",
      "how": "@Repository\nclass PostQueryRepository(private val query: JPAQueryFactory) {\n  fun search(keyword: String?): List<Post> {\n    val p = QPost.post\n    return query.selectFrom(p)\n      .where(keyword?.let { p.title.contains(it) })\n      .fetch()\n  }\n}",
      "watchOut": "Q-classes are generated at build time, so the IDE may show them red until you configure annotationProcessor and run a build. Tip: passing null to .where() is auto-ignored — leverage this for clean dynamic conditions."
    },
    "analogies_ko": [
      "JPQL이 손글씨 편지라면, QueryDSL은 워드프로세서 — 맞춤법 검사가 실시간으로 돼요."
    ],
    "analogies_en": [
      "If JPQL is a handwritten letter, QueryDSL is a word processor — spell-check runs in real time."
    ],
    "simpler_fallback": "spring-jpa-basics"
  },
  {
    "id": "spring-jpa-transactions",
    "title_en": "@Transactional",
    "title_ko": "@Transactional",
    "level": "intermediate",
    "category": "Spring Data",
    "order": 32,
    "tip_ko": "쓰기 작업이 있는 서비스 메서드엔 @Transactional. 같은 클래스 내부 호출은 프록시를 안 타니 주의하세요.",
    "tip_en": "Apply @Transactional to service methods that mutate data. Self-invocation skips the proxy, so be careful.",
    "teaching_hints_ko": {
      "what": "메서드를 트랜잭션으로 감싸 자동 커밋/롤백. JPA의 영속성 컨텍스트가 살아 있어야 dirty checking과 LAZY 로딩이 동작해요.",
      "why": "여러 DB 작업을 원자적으로 묶어 일부만 성공하는 상황을 방지. 직접 commit/rollback 호출 안 해도 돼서 코드가 깔끔해져요.",
      "how": "@Service\nclass OrderService(\n  private val orderRepo: OrderRepository\n) {\n  @Transactional\n  fun place(userId: Long, itemId: Long): Order {\n    val order = Order(userId, itemId)\n    return orderRepo.save(order)  // 영속 상태 → dirty checking 동작\n  }\n}",
      "watchOut": "같은 클래스의 다른 메서드를 this.foo()로 호출하면 프록시를 안 거쳐서 @Transactional이 무시돼요. RuntimeException만 기본 롤백, checked exception은 rollbackFor 명시 필요. 조회 전용은 @Transactional(readOnly = true)로 최적화."
    },
    "teaching_hints_en": {
      "what": "Wraps a method in a transaction with auto commit/rollback. Keeps the JPA persistence context alive so dirty checking and LAZY loading work.",
      "why": "Groups multiple DB operations atomically — no half-completed states. You don't manually call commit/rollback, keeping code clean.",
      "how": "@Service\nclass OrderService(\n  private val orderRepo: OrderRepository\n) {\n  @Transactional\n  fun place(userId: Long, itemId: Long): Order {\n    val order = Order(userId, itemId)\n    return orderRepo.save(order)  // managed → dirty checking works\n  }\n}",
      "watchOut": "Calling another method on the same class via this.foo() bypasses the proxy, so @Transactional is ignored. Only RuntimeException rolls back by default — for checked exceptions, set rollbackFor. For read-only queries use @Transactional(readOnly = true)."
    },
    "analogies_ko": [
      "은행 송금 — 출금과 입금 둘 다 성공해야 전체 성공, 하나라도 실패하면 둘 다 취소.",
      "@Transactional은 '저장 또는 전체 취소' 버튼 — 중간 상태가 남지 않게 보장해요."
    ],
    "analogies_en": [
      "A bank transfer — withdraw and deposit must both succeed, or both roll back.",
      "@Transactional is a 'save or cancel everything' button — no half-applied state."
    ],
    "simpler_fallback": "spring-jpa-basics"
  },
  {
    "id": "spring-jpa-audit",
    "title_en": "JPA Auditing",
    "title_ko": "JPA Auditing (@CreatedDate)",
    "level": "intermediate",
    "category": "Spring Data",
    "order": 33,
    "tip_ko": "createdAt/updatedAt 컬럼은 @CreatedDate, @LastModifiedDate로 자동 채우게 하세요. 수동 set은 까먹기 쉬워요.",
    "tip_en": "Auto-populate createdAt/updatedAt with @CreatedDate and @LastModifiedDate. Setting them manually is easy to forget.",
    "teaching_hints_ko": {
      "what": "Entity가 저장/수정될 때 시각, 작성자 등의 메타 정보를 자동으로 기록해주는 기능. @EnableJpaAuditing + @EntityListeners(AuditingEntityListener)로 활성화.",
      "why": "모든 테이블에 들어가는 createdAt/updatedAt을 매번 손으로 set하지 않게. 누락이나 시각 불일치를 원천 차단해요.",
      "how": "@Configuration\n@EnableJpaAuditing\nclass JpaConfig\n\n@Entity\n@EntityListeners(AuditingEntityListener::class)\nclass Post(\n  @Id @GeneratedValue val id: Long? = null,\n  @CreatedDate var createdAt: Instant? = null,\n  @LastModifiedDate var updatedAt: Instant? = null\n)",
      "watchOut": "@EnableJpaAuditing 설정을 까먹으면 어노테이션이 무시돼서 null로 저장돼요. 작성자 자동 기록(@CreatedBy)을 쓰려면 AuditorAware<Long> 빈을 따로 등록해야 해요. var여야 JPA가 값을 set할 수 있어요."
    },
    "teaching_hints_en": {
      "what": "Auto-records metadata like timestamps and authors when entities are saved or updated. Enabled via @EnableJpaAuditing + @EntityListeners(AuditingEntityListener).",
      "why": "createdAt/updatedAt belong on almost every table. Auto-population eliminates manual setters and prevents missing or inconsistent timestamps.",
      "how": "@Configuration\n@EnableJpaAuditing\nclass JpaConfig\n\n@Entity\n@EntityListeners(AuditingEntityListener::class)\nclass Post(\n  @Id @GeneratedValue val id: Long? = null,\n  @CreatedDate var createdAt: Instant? = null,\n  @LastModifiedDate var updatedAt: Instant? = null\n)",
      "watchOut": "Forget @EnableJpaAuditing and the annotations are silently ignored — fields stay null. For @CreatedBy you must register an AuditorAware<Long> bean. Fields must be var so JPA can set them."
    },
    "analogies_ko": [
      "문서에 자동으로 찍히는 타임스탬프 도장 — 사람이 매번 들고 찍을 필요 없이 시스템이 알아서.",
      "Git의 author/date 메타데이터처럼 — 직접 안 적어도 자동으로 기록돼요."
    ],
    "analogies_en": [
      "A timestamp stamp that imprints itself on every document — no need to press it manually.",
      "Like Git's author/date metadata — you don't write it, it's recorded for you."
    ],
    "simpler_fallback": "spring-jpa-basics"
  },
  {
    "id": "spring-security-basics",
    "title_en": "Spring Security Basics",
    "title_ko": "Spring Security 기초 (FilterChain, Authentication)",
    "level": "intermediate",
    "category": "Spring Security",
    "order": 34,
    "tip_ko": "Spring Security는 Servlet Filter 체인으로 동작해요. 요청은 Controller 도달 전 여러 필터를 거칩니다.",
    "tip_en": "Spring Security runs as a chain of servlet filters. Each request passes through them before reaching your controller.",
    "teaching_hints_ko": {
      "what": "인증(Authentication, '누구인가')과 인가(Authorization, '뭘 할 수 있나')를 처리하는 프레임워크. SecurityFilterChain으로 URL별 보안 정책을 선언적으로 설정.",
      "why": "직접 세션 검사, 비밀번호 해시, CSRF 토큰 다루는 건 위험. 검증된 표준 구현체에 맡겨 보안 사고를 줄여요.",
      "how": "@Configuration\n@EnableWebSecurity\nclass SecurityConfig {\n  @Bean\n  fun chain(http: HttpSecurity): SecurityFilterChain = http\n    .authorizeHttpRequests {\n      it.requestMatchers(\"/public/**\").permitAll()\n        .anyRequest().authenticated()\n    }\n    .formLogin {}\n    .build()\n}",
      "watchOut": "REST API에 .csrf().disable()을 안 끄면 POST가 403으로 막혀요. 단, 세션 기반 웹앱에선 CSRF 보호를 절대 끄지 마세요. SecurityContextHolder는 ThreadLocal이라 비동기/별도 스레드에선 인증 정보가 안 넘어가요."
    },
    "teaching_hints_en": {
      "what": "A framework for authentication ('who you are') and authorization ('what you can do'). SecurityFilterChain declaratively configures per-URL security.",
      "why": "Hand-rolling session checks, password hashing, and CSRF tokens is risky. Delegate to the battle-tested standard to prevent security incidents.",
      "how": "@Configuration\n@EnableWebSecurity\nclass SecurityConfig {\n  @Bean\n  fun chain(http: HttpSecurity): SecurityFilterChain = http\n    .authorizeHttpRequests {\n      it.requestMatchers(\"/public/**\").permitAll()\n        .anyRequest().authenticated()\n    }\n    .formLogin {}\n    .build()\n}",
      "watchOut": "For REST APIs you usually need .csrf().disable() — without it, POSTs get 403. But never disable CSRF on session-based web apps. SecurityContextHolder uses ThreadLocal, so auth info doesn't propagate to async/other threads automatically."
    },
    "analogies_ko": [
      "사옥 출입 게이트 — 1차 신분증, 2차 지문, 3차 출입 가능 층 확인. 통과하면 사무실(Controller) 도착.",
      "SecurityFilterChain은 공항 보안검색대 라인 — 여러 단계가 정해진 순서로 작동."
    ],
    "analogies_en": [
      "An office building's entry gates — ID check, fingerprint, floor authorization. Pass all and you reach the office (controller).",
      "SecurityFilterChain is an airport security line — multiple stations in a fixed order."
    ],
    "simpler_fallback": "spring-rest-controller"
  },
  {
    "id": "spring-jwt",
    "title_en": "JWT Authentication",
    "title_ko": "JWT 인증",
    "level": "intermediate",
    "category": "Spring Security",
    "order": 35,
    "tip_ko": "JWT는 서버에 세션 저장 없이 토큰 자체로 인증해요. 짧은 만료 + refresh token 조합이 기본입니다.",
    "tip_en": "JWT carries auth info in the token itself — no server session needed. Pair a short-lived access token with a refresh token.",
    "teaching_hints_ko": {
      "what": "JSON Web Token. 헤더.페이로드.서명 세 부분이 점(.)으로 연결된 문자열. 서명 덕분에 위변조 못 하고, 서버는 검증만 하면 됨.",
      "why": "세션 저장소가 필요 없어 서버를 stateless하게 운영 가능. 마이크로서비스나 모바일 API에서 확장성과 통합이 쉬워져요.",
      "how": "class JwtFilter(\n  private val parser: JwtParser\n) : OncePerRequestFilter() {\n  override fun doFilterInternal(req: HttpServletRequest, res: HttpServletResponse, chain: FilterChain) {\n    req.getHeader(\"Authorization\")?.removePrefix(\"Bearer \")?.let { token ->\n      val auth = parser.toAuthentication(token)\n      SecurityContextHolder.getContext().authentication = auth\n    }\n    chain.doFilter(req, res)\n  }\n}",
      "watchOut": "JWT는 한 번 발급되면 만료까지 회수 못 해요. 비밀번호 변경/로그아웃 즉시 무효화하려면 블랙리스트나 짧은 만료(15분) + refresh token. 페이로드는 base64일 뿐 암호화 아니니 비밀번호 같은 민감 정보 절대 넣지 마세요."
    },
    "teaching_hints_en": {
      "what": "JSON Web Token — header.payload.signature joined by dots. The signature prevents tampering, so the server only needs to verify, not store.",
      "why": "No session store required, keeping servers stateless. This makes scaling out and integrating across microservices or mobile APIs much easier.",
      "how": "class JwtFilter(\n  private val parser: JwtParser\n) : OncePerRequestFilter() {\n  override fun doFilterInternal(req: HttpServletRequest, res: HttpServletResponse, chain: FilterChain) {\n    req.getHeader(\"Authorization\")?.removePrefix(\"Bearer \")?.let { token ->\n      val auth = parser.toAuthentication(token)\n      SecurityContextHolder.getContext().authentication = auth\n    }\n    chain.doFilter(req, res)\n  }\n}",
      "watchOut": "Once issued, a JWT can't be revoked until expiry. For instant invalidation on password change/logout, use a blacklist or a short TTL (15 min) + refresh token. Payload is base64, not encrypted — never put passwords or sensitive data in it."
    },
    "analogies_ko": [
      "콘서트 손목 밴드 — 입구에서 한 번 확인받고 채우면 안에선 어디든 통과. 단, 잘라서 폐기 전엔 회수 불가.",
      "위조방지 인장이 찍힌 통행증 — 발행자만 조작 가능, 받은 쪽은 인장만 확인."
    ],
    "analogies_en": [
      "A festival wristband — checked once at entry, then accepted everywhere inside. But you can't easily revoke it without cutting it off.",
      "A tamper-proof seal — only the issuer can stamp, others just verify."
    ],
    "simpler_fallback": "spring-security-basics"
  },
  {
    "id": "spring-oauth2",
    "title_en": "OAuth2 Client",
    "title_ko": "OAuth2 클라이언트",
    "level": "advanced",
    "category": "Spring Security",
    "order": 36,
    "tip_ko": "구글/카카오 로그인은 직접 구현 말고 spring-boot-starter-oauth2-client로. 표준 흐름을 자동 처리해요.",
    "tip_en": "Don't roll your own Google/Kakao login — use spring-boot-starter-oauth2-client. It handles the standard flow.",
    "teaching_hints_ko": {
      "what": "OAuth2 Authorization Code Grant 플로우를 자동화. 사용자를 provider로 리다이렉트 → 코드 받기 → 액세스 토큰 교환 → 사용자 정보 조회까지 알아서.",
      "why": "비밀번호를 직접 저장하지 않고 외부 신원공급자(Google, Kakao)에 위임. 사용자는 새 계정 안 만들어도 되고, 우리는 비밀번호 보관 책임에서 자유로워져요.",
      "how": "// application.yml에 client-id/secret 등록 후\n@Configuration\nclass SecurityConfig {\n  @Bean\n  fun chain(http: HttpSecurity): SecurityFilterChain = http\n    .oauth2Login { it.userInfoEndpoint { ep ->\n      ep.userService(customOAuth2UserService)\n    }}\n    .build()\n}",
      "watchOut": "redirect-uri는 provider 콘솔과 application.yml이 한 글자도 안 틀리게 일치해야 해요(http/https, 슬래시 끝). state 파라미터 검증을 끄지 마세요 — CSRF 공격에 노출돼요. 토큰은 access token만 받지 말고 refresh token 받게 scope에 offline_access 등 명시."
    },
    "teaching_hints_en": {
      "what": "Automates the OAuth2 Authorization Code Grant flow. Redirects the user to the provider, exchanges the code for an access token, and fetches user info.",
      "why": "Lets you delegate identity to Google/Kakao instead of storing passwords yourself. Users skip account creation, and you avoid password-storage liability.",
      "how": "// after registering client-id/secret in application.yml\n@Configuration\nclass SecurityConfig {\n  @Bean\n  fun chain(http: HttpSecurity): SecurityFilterChain = http\n    .oauth2Login { it.userInfoEndpoint { ep ->\n      ep.userService(customOAuth2UserService)\n    }}\n    .build()\n}",
      "watchOut": "redirect-uri must match the provider console and application.yml character-for-character (http vs https, trailing slash). Never disable state-parameter validation — it protects against CSRF. To get a refresh token you usually need offline_access (or similar) in scope."
    },
    "analogies_ko": [
      "호텔 발렛 키 — 차 전체 권한이 아닌 '주차/이동만' 가능한 제한된 키를 직원에게 잠깐 빌려줌.",
      "대리인을 통한 신원 확인 — 우리가 직접 신분증 보관하지 않고 정부(provider)가 보증서를 발급해줘요."
    ],
    "analogies_en": [
      "A hotel valet key — a limited key that only parks and moves the car, never the full one.",
      "Verifying identity through an agent — we don't store the ID ourselves, the government (provider) issues a certificate."
    ],
    "simpler_fallback": "spring-security-basics"
  },
  {
    "id": "spring-role-authorization",
    "title_en": "Role-Based Authorization",
    "title_ko": "역할 기반 권한 (@PreAuthorize)",
    "level": "intermediate",
    "category": "Spring Security",
    "order": 37,
    "tip_ko": "@PreAuthorize로 메서드 단에서 권한 체크. URL 매칭보다 비즈니스 로직에 더 가까워 안전해요.",
    "tip_en": "Use @PreAuthorize to enforce permissions at the method level — closer to business logic and safer than URL matching alone.",
    "teaching_hints_ko": {
      "what": "메서드 호출 전 SpEL 표현식으로 권한을 검사하는 어노테이션. ROLE_ 접두사 자동 처리, 본인 자원만 접근 같은 동적 검사도 가능.",
      "why": "Controller가 늘어나면 URL 패턴만으로는 빠뜨리기 쉬워요. 서비스 메서드에 직접 붙이면 어떤 진입 경로로 와도 권한 체크가 보장돼요.",
      "how": "@Service\nclass PostService {\n  @PreAuthorize(\"hasRole('ADMIN')\")\n  fun delete(id: Long) { /* ... */ }\n\n  @PreAuthorize(\"#userId == authentication.principal.id\")\n  fun updateProfile(userId: Long, req: ProfileReq) { /* ... */ }\n}\n\n// 활성화\n@EnableMethodSecurity",
      "watchOut": "hasRole('ADMIN')은 자동으로 ROLE_ADMIN 찾아요 — DB에 'ADMIN'으로 저장하고 hasAuthority('ROLE_ADMIN')과 헷갈리지 마세요. role hierarchy(ADMIN > USER)는 따로 RoleHierarchy 빈 등록해야 작동. @EnableMethodSecurity 누락 시 어노테이션 그냥 무시돼요."
    },
    "teaching_hints_en": {
      "what": "Annotation that evaluates a SpEL expression before a method runs. Auto-handles the ROLE_ prefix and supports dynamic checks like 'only the owner'.",
      "why": "URL pattern matching gets fragile as controllers grow. Putting checks on service methods guarantees enforcement no matter which entry point calls them.",
      "how": "@Service\nclass PostService {\n  @PreAuthorize(\"hasRole('ADMIN')\")\n  fun delete(id: Long) { /* ... */ }\n\n  @PreAuthorize(\"#userId == authentication.principal.id\")\n  fun updateProfile(userId: Long, req: ProfileReq) { /* ... */ }\n}\n\n// enable\n@EnableMethodSecurity",
      "watchOut": "hasRole('ADMIN') auto-prefixes ROLE_ — store 'ADMIN' in DB and don't confuse it with hasAuthority('ROLE_ADMIN'). Role hierarchy (ADMIN > USER) requires a separate RoleHierarchy bean. Forget @EnableMethodSecurity and the annotations are silently ignored."
    },
    "analogies_ko": [
      "사무실 카드키 권한 — 일반 직원은 사무실만, 관리자는 서버실까지. 문(메서드)마다 어떤 권한이 필요한지 적혀 있어요.",
      "도서관 회원 등급 — 학생은 일반자료, 교수는 희귀본 — 자료 자체에 등급 표시."
    ],
    "analogies_en": [
      "Office keycard tiers — staff get the office, admins get the server room. Each door (method) lists which level it requires.",
      "Library membership tiers — students get general stacks, faculty get rare books — the policy is on the resource itself."
    ],
    "simpler_fallback": "spring-security-basics"
  },
  {
    "id": "db-normalization",
    "title_en": "Database Normalization",
    "title_ko": "정규화 (Normalization)",
    "level": "basic",
    "category": "Database",
    "order": 38,
    "tip_ko": "기본은 3NF까지. 그 이상은 성능과 트레이드오프하면서 선택적으로 적용해요.",
    "tip_en": "Aim for 3NF as a baseline. Beyond that, denormalize selectively for performance.",
    "teaching_hints_ko": {
      "what": "중복을 줄이고 데이터 이상(insert/update/delete anomaly)을 막기 위해 테이블을 작은 단위로 쪼개는 설계 원칙. 1NF(원자값) → 2NF(부분 함수 종속 제거) → 3NF(이행 함수 종속 제거).",
      "why": "한 줄 주문 테이블에 고객 이름, 상품명, 가격이 다 들어 있으면 고객 이름 바꿀 때 모든 주문 행을 수정해야 해요. 정규화하면 한 곳만 고치면 끝.",
      "how": "-- Bad: 한 테이블에 다 모음\nCREATE TABLE orders (id INT, customer_name TEXT, product TEXT, price INT);\n\n-- Good: 3NF로 분리\nCREATE TABLE customers (id INT PRIMARY KEY, name TEXT);\nCREATE TABLE products (id INT PRIMARY KEY, name TEXT, price INT);\nCREATE TABLE orders (id INT, customer_id INT REFERENCES customers, product_id INT REFERENCES products);",
      "watchOut": "지나친 정규화는 JOIN 폭탄을 만들어 조회가 느려져요. 읽기 부하가 큰 시스템은 의도적으로 비정규화(denormalization)해 캐시성 컬럼을 두는 게 정답일 때도 있어요."
    },
    "teaching_hints_en": {
      "what": "A design principle that splits tables into smaller units to remove duplication and prevent insert/update/delete anomalies. 1NF (atomic values) → 2NF (no partial dependency) → 3NF (no transitive dependency).",
      "why": "If a single orders table holds customer name, product, and price, renaming a customer means updating every order row. Normalization means changing data in one place.",
      "how": "-- Bad: everything in one table\nCREATE TABLE orders (id INT, customer_name TEXT, product TEXT, price INT);\n\n-- Good: split into 3NF\nCREATE TABLE customers (id INT PRIMARY KEY, name TEXT);\nCREATE TABLE products (id INT PRIMARY KEY, name TEXT, price INT);\nCREATE TABLE orders (id INT, customer_id INT REFERENCES customers, product_id INT REFERENCES products);",
      "watchOut": "Over-normalization causes JOIN-heavy queries that get slow. Read-heavy systems sometimes intentionally denormalize and store cached columns — that's not bad design, that's a deliberate trade-off."
    },
    "analogies_ko": [
      "옷장 정리: 셔츠는 셔츠칸, 양말은 양말칸. 같은 셔츠를 여러 칸에 두면 한 벌 버릴 때 모두 찾아 빼야 해요.",
      "주소록과 발송 이력을 따로 두는 것 — 사람 정보가 바뀌어도 발송 기록은 그대로 유지."
    ],
    "analogies_en": [
      "Closet organization: shirts in one drawer, socks in another. Storing duplicates means hunting them all down when something changes.",
      "Keeping a contact list separate from a shipping log — when a person moves, you update one place."
    ],
    "simpler_fallback": null
  },
  {
    "id": "db-indexing",
    "title_en": "Database Indexing",
    "title_ko": "인덱싱",
    "level": "basic",
    "category": "Database",
    "order": 39,
    "tip_ko": "WHERE/JOIN/ORDER BY에 자주 쓰이는 컬럼에 인덱스. 단, 쓰기 비용도 같이 늘어요.",
    "tip_en": "Index columns used often in WHERE/JOIN/ORDER BY — but remember each index slows down writes.",
    "teaching_hints_ko": {
      "what": "테이블의 특정 컬럼 값을 정렬해 별도로 보관해두는 자료구조(보통 B-tree). 풀 스캔 대신 인덱스를 따라가 빠르게 행을 찾아요.",
      "why": "수백만 행에서 email = 'tabber@x.com'을 찾을 때 인덱스가 없으면 전 행을 다 읽어요. 인덱스가 있으면 O(log N)로 끝.",
      "how": "-- 단일 컬럼 인덱스\nCREATE INDEX idx_users_email ON users(email);\n\n-- 복합 인덱스 (왼쪽 컬럼부터 매칭)\nCREATE INDEX idx_orders_user_created ON orders(user_id, created_at DESC);\n\n-- 실행 계획 확인\nEXPLAIN ANALYZE SELECT * FROM users WHERE email = 'a@b.com';",
      "watchOut": "인덱스는 INSERT/UPDATE/DELETE마다 갱신되므로 쓰기 성능을 깎아요. 카디널리티가 낮은 컬럼(예: gender)에 거는 건 효과가 거의 없어요. 복합 인덱스는 왼쪽 prefix만 매칭됩니다."
    },
    "teaching_hints_en": {
      "what": "A separate sorted data structure (usually a B-tree) over specific table columns. Instead of a full scan, the DB walks the index to locate rows fast.",
      "why": "On millions of rows, finding email = 'tabber@x.com' without an index reads every row. With an index it's O(log N).",
      "how": "-- single-column index\nCREATE INDEX idx_users_email ON users(email);\n\n-- composite index (left-prefix matching)\nCREATE INDEX idx_orders_user_created ON orders(user_id, created_at DESC);\n\n-- inspect the plan\nEXPLAIN ANALYZE SELECT * FROM users WHERE email = 'a@b.com';",
      "watchOut": "Every INSERT/UPDATE/DELETE rewrites the index, hurting write performance. Indexes on low-cardinality columns (e.g. gender) barely help. Composite indexes only match left-prefix columns."
    },
    "analogies_ko": [
      "책 뒤의 색인 — 페이지를 다 넘기지 않고 단어부터 찾아 해당 페이지로 점프.",
      "도서관 십진분류: 분류표 없이 책 찾으려면 모든 책장을 다 봐야 해요."
    ],
    "analogies_en": [
      "The index at the back of a book — jump to a word's page instead of flipping every page.",
      "Library Dewey Decimal: without it, you'd have to scan every shelf."
    ],
    "simpler_fallback": "db-normalization"
  },
  {
    "id": "db-transactions-acid",
    "title_en": "Transactions and ACID",
    "title_ko": "트랜잭션과 ACID",
    "level": "intermediate",
    "category": "Database",
    "order": 40,
    "tip_ko": "여러 쿼리가 '전부 성공 또는 전부 실패'여야 한다면 트랜잭션. ACID는 그 보장의 4가지 약속이에요.",
    "tip_en": "If multiple queries must all-succeed-or-all-fail, wrap them in a transaction. ACID is the four guarantees behind that.",
    "teaching_hints_ko": {
      "what": "트랜잭션은 하나의 논리적 작업 단위. ACID는 Atomicity(원자성), Consistency(일관성), Isolation(격리성), Durability(지속성)의 약속.",
      "why": "송금: A 계좌에서 빼고 B 계좌에 넣는 두 쿼리. 중간에 실패하면 돈이 사라져요. 트랜잭션이 둘을 한 묶음으로 처리해 둘 다 적용되거나 둘 다 취소되도록 보장.",
      "how": "BEGIN;\n  UPDATE accounts SET balance = balance - 1000 WHERE id = 1;\n  UPDATE accounts SET balance = balance + 1000 WHERE id = 2;\n  -- 문제 없으면\nCOMMIT;\n  -- 문제 있으면\n-- ROLLBACK;",
      "watchOut": "긴 트랜잭션은 락을 오래 잡아 다른 요청을 막아요. 외부 API 호출을 트랜잭션 안에서 하면 응답 지연으로 DB 락이 폭발해요. 트랜잭션은 가능한 짧게."
    },
    "teaching_hints_en": {
      "what": "A transaction is a single logical unit of work. ACID is the four guarantees: Atomicity, Consistency, Isolation, Durability.",
      "why": "Money transfer: subtract from A, add to B. If the second query fails halfway, money vanishes. A transaction bundles them so both apply or neither does.",
      "how": "BEGIN;\n  UPDATE accounts SET balance = balance - 1000 WHERE id = 1;\n  UPDATE accounts SET balance = balance + 1000 WHERE id = 2;\n  -- on success\nCOMMIT;\n  -- on failure\n-- ROLLBACK;",
      "watchOut": "Long transactions hold locks and block other requests. Calling external APIs inside a transaction means network latency stalls the DB lock — disaster. Keep transactions as short as possible."
    },
    "analogies_ko": [
      "은행 송금: 출금과 입금이 동시에 성공해야 거래 성립. 한쪽만 되면 둘 다 무효.",
      "결혼식 서약: '둘 다 yes' 아니면 식이 안 시작."
    ],
    "analogies_en": [
      "A bank transfer: withdrawal and deposit must both succeed; otherwise neither happens.",
      "A wedding vow: it counts only if both sides say yes."
    ],
    "simpler_fallback": "spring-jpa-transactions"
  },
  {
    "id": "db-isolation-levels",
    "title_en": "Isolation Levels",
    "title_ko": "격리 수준 (Isolation Levels)",
    "level": "advanced",
    "category": "Database",
    "order": 41,
    "tip_ko": "기본은 Read Committed. 더 엄격하게 가야 할 때만 Repeatable Read 이상으로 올려요.",
    "tip_en": "Read Committed is the safe default. Step up to Repeatable Read or higher only when you actually need it.",
    "teaching_hints_ko": {
      "what": "동시에 실행되는 트랜잭션들끼리 서로의 데이터를 얼마나 볼 수 있는지에 대한 SQL 표준. Read Uncommitted < Read Committed < Repeatable Read < Serializable.",
      "why": "격리가 약하면 동시성은 좋지만 dirty read, non-repeatable read, phantom read 같은 이상 현상이 생겨요. 격리가 강하면 안전하지만 락이 늘어 동시성이 떨어집니다.",
      "how": "-- PostgreSQL: 트랜잭션 시작 시 격리 수준 지정\nBEGIN ISOLATION LEVEL REPEATABLE READ;\n  SELECT balance FROM accounts WHERE id = 1;\n  -- 같은 트랜잭션 안에서 다시 읽어도 같은 값 보장\n  SELECT balance FROM accounts WHERE id = 1;\nCOMMIT;",
      "watchOut": "Serializable은 사실상 단일 스레드처럼 동작해 처리량이 급락. PostgreSQL의 'Repeatable Read'는 표준보다 더 엄격(SI 기반)해 phantom read도 막아요 — DB마다 의미가 미묘하게 달라요."
    },
    "teaching_hints_en": {
      "what": "A SQL standard describing how much concurrent transactions see of each other's data: Read Uncommitted < Read Committed < Repeatable Read < Serializable.",
      "why": "Weaker isolation means more concurrency but allows anomalies like dirty reads, non-repeatable reads, and phantom reads. Stronger means safer but more locking, less throughput.",
      "how": "-- PostgreSQL: set isolation when starting a transaction\nBEGIN ISOLATION LEVEL REPEATABLE READ;\n  SELECT balance FROM accounts WHERE id = 1;\n  -- subsequent reads in this tx see the same value\n  SELECT balance FROM accounts WHERE id = 1;\nCOMMIT;",
      "watchOut": "Serializable effectively serializes traffic — throughput tanks. PostgreSQL's Repeatable Read is stricter than the SQL standard (snapshot isolation, blocks phantoms too); semantics differ across DBs."
    },
    "analogies_ko": [
      "회의실 예약 시스템: Read Committed는 '누가 예약 확정한 것만 보임', Serializable은 '한 사람씩 줄 서서 예약'.",
      "주식 시세창: 강한 격리 = 거래 끝날 때까지 가격 고정 화면만 봄."
    ],
    "analogies_en": [
      "Meeting-room booking: Read Committed shows confirmed reservations only; Serializable forces one booker at a time.",
      "Stock ticker: strong isolation = you only see one frozen snapshot until your trade finishes."
    ],
    "simpler_fallback": "db-transactions-acid"
  },
  {
    "id": "db-deadlock",
    "title_en": "Deadlock",
    "title_ko": "데드락 (Deadlock)",
    "level": "advanced",
    "category": "Database",
    "order": 42,
    "tip_ko": "여러 행을 잠글 때는 항상 같은 순서로. 락 순서만 통일해도 데드락 대부분 사라져요.",
    "tip_en": "Always acquire locks in the same order. Consistent ordering eliminates most deadlocks.",
    "teaching_hints_ko": {
      "what": "두 트랜잭션이 서로가 가진 락을 기다리며 영원히 멈추는 상황. DB는 보통 감지해서 한쪽을 강제 롤백시켜요.",
      "why": "T1: 행 A 잠금 → 행 B 요청 / T2: 행 B 잠금 → 행 A 요청. 서로 상대를 기다리며 무한 대기. 운영 중에 갑자기 'deadlock detected' 에러로 나타나요.",
      "how": "-- T1\nBEGIN;\nUPDATE accounts SET balance = balance - 100 WHERE id = 1; -- 락 1\nUPDATE accounts SET balance = balance + 100 WHERE id = 2; -- 락 2 대기\n\n-- T2 (동시에)\nBEGIN;\nUPDATE accounts SET balance = balance - 50 WHERE id = 2;  -- 락 2\nUPDATE accounts SET balance = balance + 50 WHERE id = 1;  -- 락 1 대기 → 데드락",
      "watchOut": "ORM에서는 자동 생성된 SQL 순서가 코드 순서와 달라 발견이 어려워요. 트랜잭션이 길수록 데드락 확률도 비례해서 증가. 재시도 로직(exponential backoff)을 기본 패턴으로 둬요."
    },
    "teaching_hints_en": {
      "what": "Two transactions each hold a lock the other needs and wait forever. The DB usually detects it and rolls one back.",
      "why": "T1: lock row A → wait for row B / T2: lock row B → wait for row A. Both stuck. In production it surfaces as a sudden 'deadlock detected' error.",
      "how": "-- T1\nBEGIN;\nUPDATE accounts SET balance = balance - 100 WHERE id = 1; -- lock 1\nUPDATE accounts SET balance = balance + 100 WHERE id = 2; -- waits for lock 2\n\n-- T2 (concurrently)\nBEGIN;\nUPDATE accounts SET balance = balance - 50 WHERE id = 2;  -- lock 2\nUPDATE accounts SET balance = balance + 50 WHERE id = 1;  -- waits for lock 1 → deadlock",
      "watchOut": "With ORMs the SQL order doesn't match your code, making deadlocks hard to spot. Longer transactions linearly increase the risk. Treat retry-with-exponential-backoff as a default pattern."
    },
    "analogies_ko": [
      "좁은 복도에서 마주친 두 사람이 서로 비켜주길 기다리며 멈춘 상황.",
      "두 사람이 서로 상대 펜과 종이를 빌려야 메모할 수 있는데, 둘 다 한쪽씩만 쥐고 안 놓는 상황."
    ],
    "analogies_en": [
      "Two people in a narrow hallway each waiting for the other to step aside.",
      "Two people who each hold one of two tools the other needs — and neither lets go."
    ],
    "simpler_fallback": "db-transactions-acid"
  },
  {
    "id": "arch-caching-redis",
    "title_en": "Caching with Redis",
    "title_ko": "캐싱과 Redis",
    "level": "intermediate",
    "category": "Architecture",
    "order": 43,
    "tip_ko": "캐시는 무효화 전략이 8할. TTL과 갱신 시점을 명확히 정해두지 않으면 stale data 지옥.",
    "tip_en": "Cache strategy is 80% about invalidation. Without clear TTLs and refresh rules, you get stale-data hell.",
    "teaching_hints_ko": {
      "what": "자주 읽는 데이터를 메모리(Redis)에 두고, DB까지 가지 않고 빠르게 반환하는 기법. Cache-Aside 패턴이 가장 흔해요.",
      "why": "DB 쿼리는 수십~수백 ms, Redis는 1ms 이하. 인기 게시글, 사용자 세션, 랭킹처럼 같은 답을 자주 반복해 묻는 데이터에 효과적.",
      "how": "// Spring + Redis (Cache-Aside)\nfun getUser(id: Long): User {\n    val key = \"user:$id\"\n    redis.get(key)?.let { return parse(it) }       // 캐시 hit\n    val user = userRepo.findById(id).orElseThrow() // 캐시 miss → DB\n    redis.setex(key, 300, toJson(user))            // TTL 5분\n    return user\n}",
      "watchOut": "DB는 업데이트했는데 캐시는 안 지우면 stale data. 반대로 캐시만 지우고 DB 실패하면 데이터 불일치. Cache stampede(만료 직후 동시 요청 폭주)도 흔한 함정 — TTL에 jitter를 추가해요."
    },
    "teaching_hints_en": {
      "what": "Store frequently read data in memory (Redis) so requests skip the DB. Cache-Aside is the most common pattern.",
      "why": "DB queries take tens to hundreds of ms; Redis is sub-ms. Effective for popular posts, sessions, leaderboards — anything asked repeatedly with the same answer.",
      "how": "// Spring + Redis (Cache-Aside)\nfun getUser(id: Long): User {\n    val key = \"user:$id\"\n    redis.get(key)?.let { return parse(it) }       // cache hit\n    val user = userRepo.findById(id).orElseThrow() // cache miss → DB\n    redis.setex(key, 300, toJson(user))            // TTL 5min\n    return user\n}",
      "watchOut": "Updating the DB without invalidating the cache leaves stale data. Invalidating the cache before a failed DB write causes inconsistency. Cache stampedes (everyone hitting DB at TTL expiry) are common — add jitter to TTLs."
    },
    "analogies_ko": [
      "책상 위 자주 쓰는 책 vs 도서관 가서 빌리기 — 책상 위가 캐시.",
      "냉장고 안 우유: 매번 마트 가는 대신 가까이 두지만, 유통기한(TTL) 지나면 버려야 해요."
    ],
    "analogies_en": [
      "Books on your desk vs. trips to the library — your desk is the cache.",
      "Milk in the fridge: faster than going to the store, but it has an expiration date (TTL)."
    ],
    "simpler_fallback": "db-indexing"
  },
  {
    "id": "arch-message-queue",
    "title_en": "Message Queues",
    "title_ko": "메시지 큐 (Kafka, RabbitMQ)",
    "level": "intermediate",
    "category": "Architecture",
    "order": 44,
    "tip_ko": "동기 호출이 부담되거나 컴포넌트를 느슨하게 분리하고 싶을 때. 단순 알림에 Kafka는 과해요.",
    "tip_en": "Use it when sync calls are too costly or when you want loose coupling. Kafka is overkill for simple notifications.",
    "teaching_hints_ko": {
      "what": "송신자(Producer)가 메시지를 큐에 넣고, 수신자(Consumer)가 자기 속도로 꺼내 처리하는 비동기 통신 인프라. RabbitMQ는 작업 큐, Kafka는 이벤트 스트리밍에 강해요.",
      "why": "주문 → 결제 → 메일 → SMS를 동기 호출로 엮으면 한 단계라도 느려지면 전체가 느려요. 큐로 분리하면 결제 끝나면 즉시 응답하고, 메일/SMS는 뒤에서 처리.",
      "how": "Producer ──put──▶ [ Queue: order.created ] ──poll──▶ Consumer A (이메일)\n                                          ▲\n                                          └─poll──▶ Consumer B (SMS)\n\n특징:\n- 한 번 들어간 메시지는 처리될 때까지 보존\n- Consumer가 죽어도 메시지는 큐에 남음\n- Kafka는 이벤트를 '로그'로 보관해 재처리 가능",
      "watchOut": "Kafka는 운영 난이도(주키퍼/KRaft, 파티션, lag 모니터링)가 높아요. '그냥 비동기로 만들고 싶다' 정도면 RabbitMQ나 SQS, 심지어 DB 큐가 충분. 메시지 중복 처리(idempotency) 설계는 필수."
    },
    "teaching_hints_en": {
      "what": "Async communication infra where producers push messages and consumers pull at their own pace. RabbitMQ shines for task queues; Kafka for event streaming.",
      "why": "Chaining order → payment → email → SMS synchronously means one slow step blocks everything. With a queue, payment returns immediately and downstream work runs in the background.",
      "how": "Producer ──put──▶ [ Queue: order.created ] ──poll──▶ Consumer A (email)\n                                          ▲\n                                          └─poll──▶ Consumer B (SMS)\n\nProperties:\n- messages persist until processed\n- if a consumer crashes, messages stay queued\n- Kafka retains events as a log for replay",
      "watchOut": "Kafka has serious operational overhead (Zookeeper/KRaft, partitions, lag monitoring). For 'I just need async,' RabbitMQ, SQS, or even a DB-backed queue is plenty. Always design consumers to be idempotent."
    },
    "analogies_ko": [
      "우체국 — 보내는 사람과 받는 사람이 같은 시간에 있을 필요 없음. 우편함이 큐.",
      "식당 주문 전표: 손님은 카운터에 종이 한 장 두고 가고, 주방은 자기 페이스로 처리."
    ],
    "analogies_en": [
      "The post office — sender and receiver don't have to be present at the same time; the mailbox is the queue.",
      "Restaurant order tickets: the customer drops a slip at the counter; the kitchen processes at its own pace."
    ],
    "simpler_fallback": null
  },
  {
    "id": "arch-event-driven",
    "title_en": "Event-Driven Architecture",
    "title_ko": "이벤트 드리븐 아키텍처",
    "level": "advanced",
    "category": "Architecture",
    "order": 45,
    "tip_ko": "'무슨 일이 일어났다'를 기록하고 듣게 하면 컴포넌트 간 결합이 확 줄어요. 단, 흐름 추적이 어려워요.",
    "tip_en": "Recording 'what happened' and letting subscribers react drastically reduces coupling — but tracing flow gets harder.",
    "teaching_hints_ko": {
      "what": "서비스가 서로를 직접 호출하지 않고, 이벤트(예: OrderCreated)를 발행하면 관심 있는 다른 서비스가 구독해서 반응하는 구조.",
      "why": "주문 모듈이 '메일 보내라', 'SMS 보내라', '재고 줄여라'를 다 알아야 하면 결합도가 폭발해요. 'OrderCreated 이벤트 발행' 한 줄로 끝내고, 뒤에 누가 듣는지는 알 필요 없게.",
      "how": "[Order Service] ──emits──▶ OrderCreated ──▶ [Event Bus / Kafka]\n                                                │\n                                  ┌─────────────┼─────────────┐\n                                  ▼             ▼             ▼\n                          [Email Svc]   [Inventory]   [Analytics]\n\n각 구독자는 독립적으로 이벤트를 처리하고, 새 구독자 추가에 발행자 코드 변경 없음.",
      "watchOut": "디버깅이 악몽 — 한 요청이 어디까지 퍼졌는지 추적하려면 분산 트레이싱(OpenTelemetry 등) 필수. 이벤트 순서, 중복, 손실에 대한 합의가 없으면 데이터가 틀어져요. 작은 시스템엔 과한 설계."
    },
    "teaching_hints_en": {
      "what": "Services don't call each other directly. They emit events (e.g. OrderCreated), and interested services subscribe and react.",
      "why": "If the order module has to know about email, SMS, and inventory, coupling explodes. Emitting one OrderCreated event lets the producer stay ignorant of who listens.",
      "how": "[Order Service] ──emits──▶ OrderCreated ──▶ [Event Bus / Kafka]\n                                                │\n                                  ┌─────────────┼─────────────┐\n                                  ▼             ▼             ▼\n                          [Email Svc]   [Inventory]   [Analytics]\n\nSubscribers process independently; adding a new one requires no producer changes.",
      "watchOut": "Debugging becomes a nightmare — distributed tracing (OpenTelemetry, etc.) is mandatory to follow a request. Without agreement on event ordering, duplication, and loss, data drifts. Overkill for small systems."
    },
    "analogies_ko": [
      "라디오 방송 — 진행자는 누가 듣는지 몰라도 송출. 청취자만 채널을 맞추면 됨.",
      "병원 응급 코드 방송: 'Code Blue' 한 번 외치면 의사, 간호사, 보안이 각자 역할대로 움직임."
    ],
    "analogies_en": [
      "A radio broadcast — the host doesn't know who's listening; tune in if you want.",
      "A hospital code call: 'Code Blue' is announced once, and doctors, nurses, and security each act on their own."
    ],
    "simpler_fallback": "arch-message-queue"
  },
  {
    "id": "arch-microservices-basics",
    "title_en": "Microservices Basics",
    "title_ko": "마이크로서비스 기초",
    "level": "advanced",
    "category": "Architecture",
    "order": 46,
    "tip_ko": "팀 구조와 도메인 경계가 명확할 때만 시작. 작은 팀이라면 모놀리스가 거의 항상 옳아요.",
    "tip_en": "Start only when team structure and domain boundaries are clear. For small teams, a monolith is almost always right.",
    "teaching_hints_ko": {
      "what": "큰 애플리케이션을 도메인 단위 작은 서비스로 쪼개고, 각 서비스가 독립 배포·독립 DB·독립 스케일링을 가지는 아키텍처.",
      "why": "팀이 커지면 모놀리스 한 덩어리는 배포 충돌, 빌드 시간, 영역 침범 문제가 심해져요. 도메인별로 잘라 팀이 자기 서비스만 빠르게 릴리스하게 하려는 목적.",
      "how": "[API Gateway]\n      │\n  ┌───┼────┬─────────┐\n  ▼   ▼    ▼         ▼\n[User] [Order] [Payment] [Catalog]\n  │     │      │         │\n  DB    DB     DB        DB   ← 각자 자기 DB\n\n서비스 간 통신: REST/gRPC(동기) + 이벤트(비동기)",
      "watchOut": "분산 시스템의 모든 함정이 새로 등장: 네트워크 실패, 부분 장애, 분산 트랜잭션, 데이터 일관성. 'Distributed monolith'(서비스는 쪼갰지만 서로 강결합)는 모놀리스보다 더 나빠요. Conway's Law 잊지 마세요 — 조직 구조와 안 맞으면 실패."
    },
    "teaching_hints_en": {
      "what": "Split a large app into small domain-owned services that deploy, scale, and own data independently.",
      "why": "As teams grow, a single monolith causes deploy conflicts, slow builds, and territorial code. Splitting by domain lets each team release on its own pace.",
      "how": "[API Gateway]\n      │\n  ┌───┼────┬─────────┐\n  ▼   ▼    ▼         ▼\n[User] [Order] [Payment] [Catalog]\n  │     │      │         │\n  DB    DB     DB        DB   ← each has its own DB\n\nInter-service: REST/gRPC (sync) + events (async)",
      "watchOut": "All the joys of distributed systems show up: network failures, partial outages, distributed transactions, data consistency. A 'distributed monolith' (split services that are still tightly coupled) is worse than the original monolith. Remember Conway's Law — misalignment with org structure dooms it."
    },
    "analogies_ko": [
      "대형 마트 한 채 vs 동네 전문점 거리 — 후자는 가게마다 독립 영업, 화재 한 곳이 전체로 안 번짐.",
      "오케스트라 vs 여러 밴드: 큰 합주는 지휘자 하나 멈추면 다 멈추지만, 밴드들은 각자 연주 가능."
    ],
    "analogies_en": [
      "One mega-store vs. a street of specialty shops — each shop runs independently, a fire in one doesn't take down everything.",
      "Orchestra vs. many bands: in an orchestra one conductor stops everything; bands play independently."
    ],
    "simpler_fallback": "arch-message-queue"
  },
  {
    "id": "test-junit5",
    "title_en": "JUnit5 Basics",
    "title_ko": "JUnit5 기초",
    "level": "basic",
    "category": "Testing",
    "order": 47,
    "tip_ko": "given-when-then으로 구조화하고, 테스트 한 개당 검증 한 가지에 집중하세요.",
    "tip_en": "Structure tests as given-when-then; one assertion focus per test.",
    "teaching_hints_ko": {
      "what": "Java/Kotlin 표준 테스트 프레임워크. @Test로 테스트 메서드, @BeforeEach/@AfterEach로 셋업/정리, assertEquals로 검증.",
      "why": "테스트가 없으면 리팩터링이 도박이에요. JUnit5는 모듈식 구조(jupiter)와 람다 친화적 API로 Kotlin과 잘 맞아요.",
      "how": "import org.junit.jupiter.api.Test\nimport org.junit.jupiter.api.Assertions.*\n\nclass CalculatorTest {\n    @Test\n    fun `더하기는 두 수의 합을 반환한다`() {\n        // given\n        val calc = Calculator()\n        // when\n        val result = calc.add(2, 3)\n        // then\n        assertEquals(5, result)\n    }\n}",
      "watchOut": "테스트 이름이 'test1' 같으면 실패할 때 의미 파악 0. Kotlin은 백틱으로 한글/공백 이름 가능하니 적극 활용. 한 테스트에서 여러 가지 검증을 다 하면 실패 원인 추적이 어려워요."
    },
    "teaching_hints_en": {
      "what": "The standard Java/Kotlin testing framework. @Test marks tests, @BeforeEach/@AfterEach handle setup/teardown, assertEquals verifies results.",
      "why": "Without tests, refactoring is gambling. JUnit5's modular Jupiter design and lambda-friendly API pair well with Kotlin.",
      "how": "import org.junit.jupiter.api.Test\nimport org.junit.jupiter.api.Assertions.*\n\nclass CalculatorTest {\n    @Test\n    fun `add returns the sum of two numbers`() {\n        // given\n        val calc = Calculator()\n        // when\n        val result = calc.add(2, 3)\n        // then\n        assertEquals(5, result)\n    }\n}",
      "watchOut": "Names like 'test1' tell you nothing on failure. Use Kotlin backtick names freely. Cramming many assertions into one test makes failure diagnosis painful."
    },
    "analogies_ko": [
      "요리 레시피 검수 — 매 단계 결과가 예상과 일치하는지 확인.",
      "건강검진 항목별 검사: 한 검사로 모든 병을 진단 안 해요. 항목별로 나눠야 어디가 이상인지 알아요."
    ],
    "analogies_en": [
      "Reviewing a recipe step by step — verify each step matches expectations.",
      "A medical check-up: a single test doesn't diagnose every illness; separated tests reveal what's wrong."
    ],
    "simpler_fallback": null
  },
  {
    "id": "test-mockk",
    "title_en": "Mocking with MockK",
    "title_ko": "MockK로 Mocking",
    "level": "intermediate",
    "category": "Testing",
    "order": 48,
    "tip_ko": "외부 의존성(DB, API)을 mocking해 단위 테스트를 빠르고 결정적으로. 단, 도메인 로직은 mock 말고 실제로 돌려요.",
    "tip_en": "Mock external dependencies (DB, APIs) for fast, deterministic unit tests — but never mock the domain logic you're testing.",
    "teaching_hints_ko": {
      "what": "Kotlin 친화 mocking 라이브러리. every {} returns 로 가짜 동작 정의, verify {} 로 호출 확인.",
      "why": "DB나 외부 API에 실제로 붙으면 테스트가 느려지고 환경에 의존해요. MockK로 가짜 객체를 주입하면 빠르고 격리된 단위 테스트가 가능.",
      "how": "import io.mockk.*\nimport org.junit.jupiter.api.Test\nimport org.junit.jupiter.api.Assertions.*\n\nclass UserServiceTest {\n    @Test\n    fun `존재하지 않는 유저면 예외를 던진다`() {\n        val repo = mockk<UserRepository>()\n        every { repo.findById(999) } returns null\n        val service = UserService(repo)\n\n        assertThrows<UserNotFoundException> { service.getName(999) }\n        verify(exactly = 1) { repo.findById(999) }\n    }\n}",
      "watchOut": "Mock 남용은 '구현을 테스트'하게 만들어요 — 리팩터링하면 테스트가 와르르 깨짐. 진짜 검증해야 할 비즈니스 로직은 절대 mock하지 말고, 가장자리(외부 시스템)만 mock. final class는 mockkClass나 setting 필요."
    },
    "teaching_hints_en": {
      "what": "A Kotlin-friendly mocking library. Define fake behavior with `every {} returns`, assert calls with `verify {}`.",
      "why": "Hitting real DBs or APIs makes tests slow and environment-dependent. MockK lets you inject fakes for fast, isolated unit tests.",
      "how": "import io.mockk.*\nimport org.junit.jupiter.api.Test\nimport org.junit.jupiter.api.Assertions.*\n\nclass UserServiceTest {\n    @Test\n    fun `throws when user does not exist`() {\n        val repo = mockk<UserRepository>()\n        every { repo.findById(999) } returns null\n        val service = UserService(repo)\n\n        assertThrows<UserNotFoundException> { service.getName(999) }\n        verify(exactly = 1) { repo.findById(999) }\n    }\n}",
      "watchOut": "Over-mocking turns tests into implementation snapshots — any refactor breaks them. Never mock the business logic you're testing; only mock the edges (external systems). Final classes need mockkClass or extra config."
    },
    "analogies_ko": [
      "영화 촬영 더미: 진짜 폭탄 안 터뜨리고 가짜로 연기. 안전하고 빠르게 장면 확인.",
      "비행 시뮬레이터: 실제 비행기 안 띄우고 조종 능력 테스트."
    ],
    "analogies_en": [
      "Movie stunt dummies: instead of detonating real explosives, you fake the scene safely and quickly.",
      "A flight simulator: test piloting skills without flying a real plane."
    ],
    "simpler_fallback": "test-junit5"
  },
  {
    "id": "test-integration",
    "title_en": "Spring Integration Testing",
    "title_ko": "Spring 통합 테스트 (@SpringBootTest)",
    "level": "intermediate",
    "category": "Testing",
    "order": 49,
    "tip_ko": "단위 테스트가 80%, 통합 테스트는 핵심 시나리오 20%. 통합이 너무 많아지면 빌드가 정체돼요.",
    "tip_en": "Roughly 80% unit, 20% integration on critical paths. Too many integration tests stall your build.",
    "teaching_hints_ko": {
      "what": "Spring 컨텍스트를 실제로 띄워 컨트롤러+서비스+레포지토리+DB까지 한 번에 검증하는 테스트. @SpringBootTest + Testcontainers 조합이 표준.",
      "why": "단위 테스트가 다 통과해도 결합되는 순간 깨지는 버그가 흔해요. 트랜잭션 경계, JPA 매핑, JSON 직렬화 같은 건 통합에서만 잡혀요.",
      "how": "@SpringBootTest\n@AutoConfigureMockMvc\nclass UserApiTest @Autowired constructor(\n    val mockMvc: MockMvc\n) {\n    @Test\n    fun `GET users returns 200`() {\n        mockMvc.get(\"/users/1\")\n            .andExpect { status { isOk() } }\n            .andExpect { jsonPath(\"$.name\") { value(\"Tabber\") } }\n    }\n}",
      "watchOut": "@SpringBootTest는 컨텍스트 로딩이 느려 한 클래스가 5~10초씩 먹어요. 슬라이스 테스트(@WebMvcTest, @DataJpaTest)로 필요한 부분만 띄우면 훨씬 빨라요. H2는 운영 DB(PostgreSQL)와 동작이 달라 함정이 많으니 Testcontainers 권장."
    },
    "teaching_hints_en": {
      "what": "Boots a real Spring context to test controller + service + repository + DB end-to-end. @SpringBootTest + Testcontainers is the standard combo.",
      "why": "Unit tests can all pass while integration breaks. Transaction boundaries, JPA mappings, JSON serialization — these only surface in integration.",
      "how": "@SpringBootTest\n@AutoConfigureMockMvc\nclass UserApiTest @Autowired constructor(\n    val mockMvc: MockMvc\n) {\n    @Test\n    fun `GET users returns 200`() {\n        mockMvc.get(\"/users/1\")\n            .andExpect { status { isOk() } }\n            .andExpect { jsonPath(\"$.name\") { value(\"Tabber\") } }\n    }\n}",
      "watchOut": "@SpringBootTest is slow — context loading eats 5–10s per class. Use slice tests (@WebMvcTest, @DataJpaTest) to load only what you need. H2 behaves differently from production PostgreSQL — prefer Testcontainers for realism."
    },
    "analogies_ko": [
      "부품 검수 vs 완성차 시승 — 부품이 다 통과해도 차에 조립하면 떨림. 통합 테스트가 시승.",
      "리허설: 배우 한 명씩 연기 잘해도 무대에 다 모이면 큐가 안 맞을 수 있어요."
    ],
    "analogies_en": [
      "Part inspection vs. test-driving the finished car — parts can pass and the car still rattle. Integration tests are the test drive.",
      "A dress rehearsal: each actor is fine alone, but cues only sync up when everyone's on stage."
    ],
    "simpler_fallback": "test-junit5"
  },
  {
    "id": "devops-docker-basics",
    "title_en": "Docker Basics",
    "title_ko": "Docker 기초",
    "level": "basic",
    "category": "DevOps",
    "order": 50,
    "tip_ko": "이미지는 작게, 레이어는 캐시 잘 타게. multi-stage build와 .dockerignore는 거의 항상 정답이에요.",
    "tip_en": "Keep images small and leverage layer caching. Multi-stage builds and .dockerignore are almost always the right call.",
    "teaching_hints_ko": {
      "what": "애플리케이션과 의존성, 런타임을 한 덩어리(이미지)로 묶어 어디서든 똑같이 실행하는 컨테이너 기술. Dockerfile로 이미지를 정의해요.",
      "why": "'내 컴퓨터에선 됐는데' 문제 해결의 표준. 로컬, CI, 서버 어디서나 같은 환경. 배포 단위가 OS-수준으로 일정해져요.",
      "how": "# Spring Boot 앱 dockerizing (multi-stage)\nFROM gradle:8-jdk17 AS build\nWORKDIR /app\nCOPY . .\nRUN gradle bootJar --no-daemon\n\nFROM eclipse-temurin:17-jre\nWORKDIR /app\nCOPY --from=build /app/build/libs/*.jar app.jar\nEXPOSE 8080\nENTRYPOINT [\"java\", \"-jar\", \"app.jar\"]\n\n# 빌드/실행\n# docker build -t myapp .\n# docker run -p 8080:8080 myapp",
      "watchOut": "FROM ubuntu:latest 같은 큰 베이스는 이미지 크기가 GB 단위. JRE-slim이나 distroless를 쓰세요. COPY . . 다음에 빌드를 돌리면 소스 변경마다 의존성도 다시 받아요 — 의존성 파일 먼저 COPY해서 캐시를 살리는 게 핵심. .dockerignore 없으면 .git, node_modules가 통째로 들어가요."
    },
    "teaching_hints_en": {
      "what": "Container technology that bundles app, dependencies, and runtime into one image so it runs the same anywhere. Dockerfiles describe the image.",
      "why": "The standard fix for 'works on my machine.' Local, CI, and prod all run identical environments. Deploy unit becomes consistent at the OS level.",
      "how": "# Dockerize a Spring Boot app (multi-stage)\nFROM gradle:8-jdk17 AS build\nWORKDIR /app\nCOPY . .\nRUN gradle bootJar --no-daemon\n\nFROM eclipse-temurin:17-jre\nWORKDIR /app\nCOPY --from=build /app/build/libs/*.jar app.jar\nEXPOSE 8080\nENTRYPOINT [\"java\", \"-jar\", \"app.jar\"]\n\n# build/run\n# docker build -t myapp .\n# docker run -p 8080:8080 myapp",
      "watchOut": "Large bases like ubuntu:latest produce GB-sized images — use JRE-slim or distroless. `COPY . .` before installing deps re-downloads them on every source change; copy dependency files first to keep the cache. Without a .dockerignore, .git and node_modules sneak into the image."
    },
    "analogies_ko": [
      "택배 박스 — 내용물(앱)과 충전재(의존성)를 함께 포장해 어디로 보내도 그대로 도착.",
      "캠핑 키트: 텐트, 버너, 식기를 한 가방에. 어느 캠핑장에 가도 똑같이 쓸 수 있어요."
    ],
    "analogies_en": [
      "A shipping box — pack the contents (app) and packing material (dependencies) so it arrives intact anywhere.",
      "A camping kit: tent, stove, cookware in one bag — works the same at any campsite."
    ],
    "simpler_fallback": null
  }
];
