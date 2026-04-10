export const curriculum = [
  {
    "id": "swift-variables",
    "title_en": "Variables and Constants",
    "title_ko": "변수와 상수 (var, let)",
    "level": "beginner",
    "category": "basics",
    "order": 1,
    "tip_ko": "기본적으로 let을 쓰고, 변경이 필요할 때만 var를 써요",
    "tip_en": "Default to let, only use var when mutation is needed",
    "teaching_hints_ko": {
      "what": "데이터를 저장하는 이름 붙은 공간. var는 변경 가능, let은 변경 불가",
      "why": "프로그램에서 데이터를 기억하고 재사용하기 위해 필요",
      "how": "let name = \"Swift\"\nvar count = 0\ncount += 1",
      "watchOut": "let으로 선언한 값을 변경하면 컴파일 에러"
    },
    "teaching_hints_en": {
      "what": "Named storage for data. var is mutable, let is immutable",
      "why": "Needed to remember and reuse data in your program",
      "how": "let name = \"Swift\"\nvar count = 0\ncount += 1",
      "watchOut": "Changing a let constant causes a compile error"
    },
    "analogies_ko": [
      "let은 펜으로 쓴 이름표, var는 화이트보드 마커"
    ],
    "analogies_en": [
      "let is written in pen, var is written in pencil"
    ],
    "simpler_fallback": null
  },
  {
    "id": "swift-type-annotations",
    "title_en": "Type Annotations",
    "title_ko": "타입 명시 (Type Annotations)",
    "level": "beginner",
    "category": "types",
    "order": 2,
    "tip_ko": "Swift는 타입 추론이 강력해서 대부분 생략 가능하지만, 복잡할 때는 명시하는 게 좋아요",
    "tip_en": "Swift's type inference is powerful, but explicit annotations help readability in complex cases",
    "teaching_hints_ko": {
      "what": "변수나 상수의 타입을 콜론(:) 뒤에 직접 적어주는 것",
      "why": "컴파일러가 타입을 확실히 알게 하고, 코드 읽기가 쉬워짐",
      "how": "let age: Int = 25\nlet name: String = \"Kim\"\nvar pi: Double = 3.14",
      "watchOut": "타입과 맞지 않는 값을 넣으면 컴파일 에러가 발생"
    },
    "teaching_hints_en": {
      "what": "Explicitly declaring the type of a variable or constant using a colon",
      "why": "Helps the compiler and makes code more readable in complex cases",
      "how": "let age: Int = 25\nlet name: String = \"Kim\"\nvar pi: Double = 3.14",
      "watchOut": "Assigning a value that doesn't match the declared type causes a compile error"
    },
    "analogies_ko": [
      "상자에 '과일 전용'이라고 라벨을 붙이는 것"
    ],
    "analogies_en": [
      "Labeling a box 'fruits only' so nothing else goes in"
    ],
    "simpler_fallback": null
  },
  {
    "id": "swift-if-else",
    "title_en": "If-Else Statements",
    "title_ko": "조건문 (if-else)",
    "level": "beginner",
    "category": "control-flow",
    "order": 3,
    "tip_ko": "조건이 Bool 타입이어야 해요. 0이나 빈 문자열은 자동으로 false가 되지 않아요",
    "tip_en": "Conditions must be Bool — 0 and empty strings are not automatically false",
    "teaching_hints_ko": {
      "what": "조건에 따라 다른 코드를 실행하는 분기문",
      "why": "프로그램이 상황에 맞게 다르게 동작해야 할 때 필요",
      "how": "let score = 85\nif score >= 90 {\n    print(\"A\")\n} else if score >= 80 {\n    print(\"B\")\n} else {\n    print(\"C\")\n}",
      "watchOut": "조건에 괄호가 필수가 아니지만, 중괄호 {}는 반드시 필요"
    },
    "teaching_hints_en": {
      "what": "Branching statements that execute different code based on conditions",
      "why": "Needed when your program must behave differently depending on the situation",
      "how": "let score = 85\nif score >= 90 {\n    print(\"A\")\n} else if score >= 80 {\n    print(\"B\")\n} else {\n    print(\"C\")\n}",
      "watchOut": "Parentheses around conditions are optional, but curly braces {} are required"
    },
    "analogies_ko": [
      "갈림길에서 이정표를 보고 방향을 선택하는 것"
    ],
    "analogies_en": [
      "Choosing which path to take at a fork in the road"
    ],
    "simpler_fallback": null
  },
  {
    "id": "swift-for-loops",
    "title_en": "For Loops",
    "title_ko": "반복문 (for-in)",
    "level": "beginner",
    "category": "control-flow",
    "order": 4,
    "tip_ko": "반복 변수를 안 쓸 때는 _ 로 무시할 수 있어요",
    "tip_en": "Use _ to ignore the loop variable when you don't need it",
    "teaching_hints_ko": {
      "what": "컬렉션이나 범위의 각 요소에 대해 코드를 반복 실행",
      "why": "같은 작업을 여러 번 해야 할 때 코드 중복을 줄여줌",
      "how": "for i in 1...5 {\n    print(i)\n}\nlet fruits = [\"apple\", \"banana\"]\nfor fruit in fruits {\n    print(fruit)\n}",
      "watchOut": "C 스타일 for(;;)는 Swift에서 지원하지 않음"
    },
    "teaching_hints_en": {
      "what": "Repeats code for each element in a collection or range",
      "why": "Avoids code duplication when the same operation needs to run multiple times",
      "how": "for i in 1...5 {\n    print(i)\n}\nlet fruits = [\"apple\", \"banana\"]\nfor fruit in fruits {\n    print(fruit)\n}",
      "watchOut": "C-style for(;;) loops are not supported in Swift"
    },
    "analogies_ko": [
      "출석부를 한 명씩 호명하는 것"
    ],
    "analogies_en": [
      "Calling attendance one name at a time from a list"
    ],
    "simpler_fallback": null
  },
  {
    "id": "swift-optionals",
    "title_en": "Optionals",
    "title_ko": "옵셔널 (Optional)",
    "level": "beginner",
    "category": "types",
    "order": 5,
    "tip_ko": "강제 언래핑(!)보다 if-let이나 guard-let을 습관처럼 써요",
    "tip_en": "Prefer if-let or guard-let over force unwrapping (!)",
    "teaching_hints_ko": {
      "what": "값이 있을 수도, nil일 수도 있는 타입. ?를 붙여 선언",
      "why": "값이 없는 상황을 안전하게 처리하기 위한 Swift의 핵심 장치",
      "how": "var nickname: String? = nil\nnickname = \"Swift\"\nif let name = nickname {\n    print(name)\n}",
      "watchOut": "!로 강제 언래핑하면 nil일 때 런타임 크래시 발생"
    },
    "teaching_hints_en": {
      "what": "A type that can hold a value or nil. Declared with ?",
      "why": "Swift's core mechanism for safely handling the absence of a value",
      "how": "var nickname: String? = nil\nnickname = \"Swift\"\nif let name = nickname {\n    print(name)\n}",
      "watchOut": "Force unwrapping (!) crashes at runtime if the value is nil"
    },
    "analogies_ko": [
      "택배 상자를 열어봐야 안에 물건이 있는지 아는 것"
    ],
    "analogies_en": [
      "A gift box that might be empty — you have to open it to find out"
    ],
    "simpler_fallback": "swift-variables"
  },
  {
    "id": "swift-functions",
    "title_en": "Functions",
    "title_ko": "함수 (func)",
    "level": "beginner",
    "category": "functions",
    "order": 6,
    "tip_ko": "함수 이름은 동사로 시작하고, 파라미터 레이블을 잘 활용하면 영어 문장처럼 읽혀요",
    "tip_en": "Name functions with verbs and use argument labels so call sites read like English",
    "teaching_hints_ko": {
      "what": "특정 작업을 수행하는 코드 묶음. func 키워드로 선언",
      "why": "코드를 재사용하고 논리를 깔끔하게 정리하기 위해 필요",
      "how": "func greet(name: String) -> String {\n    return \"Hello, \\(name)!\"\n}\nlet message = greet(name: \"Swift\")",
      "watchOut": "반환 타입을 선언했으면 모든 경로에서 return 해야 함"
    },
    "teaching_hints_en": {
      "what": "A named block of code that performs a specific task. Declared with func",
      "why": "Enables code reuse and keeps logic organized",
      "how": "func greet(name: String) -> String {\n    return \"Hello, \\(name)!\"\n}\nlet message = greet(name: \"Swift\")",
      "watchOut": "All code paths must return a value if a return type is declared"
    },
    "analogies_ko": [
      "자판기 버튼: 입력(동전)을 넣고 결과(음료)를 받는 것"
    ],
    "analogies_en": [
      "A vending machine button: put in input, get output"
    ],
    "simpler_fallback": "swift-variables"
  },
  {
    "id": "swift-arrays",
    "title_en": "Arrays",
    "title_ko": "배열 (Array)",
    "level": "beginner",
    "category": "types",
    "order": 7,
    "tip_ko": "빈 배열 생성 시 타입을 명시해야 해요: var items: [String] = []",
    "tip_en": "Specify the type when creating empty arrays: var items: [String] = []",
    "teaching_hints_ko": {
      "what": "같은 타입의 값을 순서대로 저장하는 컬렉션",
      "why": "여러 데이터를 하나로 묶어 관리하고 반복 처리할 때 필요",
      "how": "var colors = [\"red\", \"green\", \"blue\"]\ncolors.append(\"yellow\")\nprint(colors[0])  // red\nprint(colors.count)  // 4",
      "watchOut": "범위를 벗어난 인덱스에 접근하면 런타임 크래시 발생"
    },
    "teaching_hints_en": {
      "what": "An ordered collection of values of the same type",
      "why": "Groups multiple values together for iteration and management",
      "how": "var colors = [\"red\", \"green\", \"blue\"]\ncolors.append(\"yellow\")\nprint(colors[0])  // red\nprint(colors.count)  // 4",
      "watchOut": "Accessing an out-of-bounds index causes a runtime crash"
    },
    "analogies_ko": [
      "번호가 매겨진 사물함 칸"
    ],
    "analogies_en": [
      "Numbered lockers in a row"
    ],
    "simpler_fallback": "swift-variables"
  },
  {
    "id": "swift-dictionaries",
    "title_en": "Dictionaries",
    "title_ko": "딕셔너리 (Dictionary)",
    "level": "beginner",
    "category": "types",
    "order": 8,
    "tip_ko": "딕셔너리에서 값을 꺼내면 항상 옵셔널이에요. 기본값을 지정하려면 default 파라미터를 써요",
    "tip_en": "Dictionary lookups always return optionals. Use default: to provide a fallback",
    "teaching_hints_ko": {
      "what": "키-값 쌍으로 데이터를 저장하는 컬렉션. 순서 없음",
      "why": "이름이나 ID로 빠르게 값을 찾고 싶을 때 유용",
      "how": "var scores = [\"Kim\": 90, \"Lee\": 85]\nscores[\"Park\"] = 95\nlet kimScore = scores[\"Kim\", default: 0]",
      "watchOut": "존재하지 않는 키로 접근하면 nil이 반환됨 (크래시는 아님)"
    },
    "teaching_hints_en": {
      "what": "A collection of key-value pairs with no defined order",
      "why": "Useful when you need fast lookups by name or ID",
      "how": "var scores = [\"Kim\": 90, \"Lee\": 85]\nscores[\"Park\"] = 95\nlet kimScore = scores[\"Kim\", default: 0]",
      "watchOut": "Accessing a missing key returns nil, not a crash"
    },
    "analogies_ko": [
      "전화번호부: 이름(키)으로 번호(값)를 찾는 것"
    ],
    "analogies_en": [
      "A phone book: look up a name (key) to find a number (value)"
    ],
    "simpler_fallback": "swift-arrays"
  },
  {
    "id": "swift-string-interpolation",
    "title_en": "String Interpolation",
    "title_ko": "문자열 보간 (String Interpolation)",
    "level": "beginner",
    "category": "basics",
    "order": 9,
    "tip_ko": "\\() 안에 연산이나 함수 호출도 넣을 수 있어요",
    "tip_en": "You can put expressions and function calls inside \\()",
    "teaching_hints_ko": {
      "what": "문자열 안에 변수나 표현식을 \\()로 삽입하는 기능",
      "why": "문자열 연결(+)보다 읽기 쉽고 간편하게 동적 텍스트를 만들 수 있음",
      "how": "let name = \"Swift\"\nlet version = 6\nlet msg = \"\\(name) \\(version) is great!\"\nprint(\"2 + 3 = \\(2 + 3)\")",
      "watchOut": "큰따옴표 안의 역슬래시를 빠뜨리면 문법 에러"
    },
    "teaching_hints_en": {
      "what": "Inserting variables and expressions into strings using \\()",
      "why": "Cleaner and more readable than string concatenation with +",
      "how": "let name = \"Swift\"\nlet version = 6\nlet msg = \"\\(name) \\(version) is great!\"\nprint(\"2 + 3 = \\(2 + 3)\")",
      "watchOut": "Forgetting the backslash before the parenthesis causes a syntax error"
    },
    "analogies_ko": [
      "편지 양식에 이름 칸만 바꿔 넣는 것"
    ],
    "analogies_en": [
      "A form letter where you fill in the blanks"
    ],
    "simpler_fallback": "swift-variables"
  },
  {
    "id": "swift-switch",
    "title_en": "Switch Statements",
    "title_ko": "스위치문 (switch)",
    "level": "beginner",
    "category": "control-flow",
    "order": 10,
    "tip_ko": "Swift switch는 자동으로 break되므로 fallthrough가 필요할 때만 명시해요",
    "tip_en": "Swift switch doesn't fall through by default — use fallthrough keyword explicitly",
    "teaching_hints_ko": {
      "what": "하나의 값을 여러 패턴과 비교해 매칭되는 코드를 실행",
      "why": "여러 경우를 비교할 때 if-else보다 깔끔하고 빠짐없이 처리 가능",
      "how": "let grade = \"A\"\nswitch grade {\ncase \"A\":\n    print(\"Excellent\")\ncase \"B\":\n    print(\"Good\")\ndefault:\n    print(\"Try harder\")\n}",
      "watchOut": "모든 경우를 처리해야 해서 default가 거의 항상 필요"
    },
    "teaching_hints_en": {
      "what": "Compares a value against multiple patterns and runs the matched case",
      "why": "Cleaner than if-else chains and enforces exhaustive handling",
      "how": "let grade = \"A\"\nswitch grade {\ncase \"A\":\n    print(\"Excellent\")\ncase \"B\":\n    print(\"Good\")\ndefault:\n    print(\"Try harder\")\n}",
      "watchOut": "Switch must be exhaustive — a default case is almost always needed"
    },
    "analogies_ko": [
      "교통 신호등: 빨강/노랑/초록에 따라 다르게 행동"
    ],
    "analogies_en": [
      "A traffic light: different actions for red, yellow, green"
    ],
    "simpler_fallback": "swift-if-else"
  },
  {
    "id": "swift-while-loops",
    "title_en": "While Loops",
    "title_ko": "While 반복문",
    "level": "beginner",
    "category": "control-flow",
    "order": 11,
    "tip_ko": "무한 루프가 걱정되면 반복 횟수 제한용 카운터를 함께 써요",
    "tip_en": "Add a counter to prevent infinite loops when the exit condition is complex",
    "teaching_hints_ko": {
      "what": "조건이 true인 동안 코드를 계속 반복 실행",
      "why": "반복 횟수를 미리 모를 때 유용. 조건이 만족될 때까지 실행",
      "how": "var count = 0\nwhile count < 5 {\n    print(count)\n    count += 1\n}\n// repeat-while은 최소 1번 실행\nrepeat {\n    print(\"once\")\n} while false",
      "watchOut": "조건이 영원히 true면 무한 루프에 빠짐"
    },
    "teaching_hints_en": {
      "what": "Repeats code as long as a condition is true",
      "why": "Useful when you don't know the number of iterations in advance",
      "how": "var count = 0\nwhile count < 5 {\n    print(count)\n    count += 1\n}\n// repeat-while runs at least once\nrepeat {\n    print(\"once\")\n} while false",
      "watchOut": "If the condition never becomes false, you get an infinite loop"
    },
    "analogies_ko": [
      "물이 끓을 때까지 계속 불을 켜두는 것"
    ],
    "analogies_en": [
      "Keeping the stove on until the water boils"
    ],
    "simpler_fallback": "swift-for-loops"
  },
  {
    "id": "swift-tuples",
    "title_en": "Tuples",
    "title_ko": "튜플 (Tuple)",
    "level": "beginner",
    "category": "types",
    "order": 12,
    "tip_ko": "요소가 3개 이상이면 struct를 고려해요. 튜플은 간단한 묶음에만 쓰는 게 좋아요",
    "tip_en": "If you need more than 3 elements, consider using a struct instead",
    "teaching_hints_ko": {
      "what": "서로 다른 타입의 값을 하나로 묶는 가벼운 자료구조",
      "why": "함수에서 여러 값을 한번에 반환할 때 유용",
      "how": "let person = (name: \"Kim\", age: 30)\nprint(person.name)\nprint(person.age)\n\nfunc divide(_ a: Int, by b: Int) -> (quotient: Int, remainder: Int) {\n    return (a / b, a % b)\n}",
      "watchOut": "튜플은 프로토콜을 채택할 수 없어서 복잡한 데이터에는 부적합"
    },
    "teaching_hints_en": {
      "what": "A lightweight grouping of values that can have different types",
      "why": "Useful for returning multiple values from a function",
      "how": "let person = (name: \"Kim\", age: 30)\nprint(person.name)\nprint(person.age)\n\nfunc divide(_ a: Int, by b: Int) -> (quotient: Int, remainder: Int) {\n    return (a / b, a % b)\n}",
      "watchOut": "Tuples can't conform to protocols — use structs for complex data"
    },
    "analogies_ko": [
      "여행 가방에 여권, 지갑, 폰을 함께 넣는 것"
    ],
    "analogies_en": [
      "Packing your passport, wallet, and phone together in one bag"
    ],
    "simpler_fallback": "swift-variables"
  },
  {
    "id": "swift-closures",
    "title_en": "Closures",
    "title_ko": "클로저 (Closure)",
    "level": "basic",
    "category": "closures",
    "order": 13,
    "tip_ko": "후행 클로저 문법을 쓰면 코드가 훨씬 깔끔해져요",
    "tip_en": "Trailing closure syntax makes code much cleaner",
    "teaching_hints_ko": {
      "what": "이름 없는 함수. 변수에 저장하거나 다른 함수에 전달 가능",
      "why": "콜백, 정렬 기준, 비동기 작업 등에서 코드를 간결하게 전달할 수 있음",
      "how": "let numbers = [3, 1, 2]\nlet sorted = numbers.sorted { $0 < $1 }\n\nlet greet = { (name: String) -> String in\n    return \"Hello, \\(name)\"\n}",
      "watchOut": "클로저가 self를 캡처하면 순환 참조가 생길 수 있음"
    },
    "teaching_hints_en": {
      "what": "Anonymous functions that can be stored in variables or passed to other functions",
      "why": "Enable callbacks, custom sort logic, and concise async patterns",
      "how": "let numbers = [3, 1, 2]\nlet sorted = numbers.sorted { $0 < $1 }\n\nlet greet = { (name: String) -> String in\n    return \"Hello, \\(name)\"\n}",
      "watchOut": "Closures capturing self can cause retain cycles"
    },
    "analogies_ko": [
      "전달할 수 있는 레시피 카드"
    ],
    "analogies_en": [
      "A recipe card you can hand to someone else to execute"
    ],
    "simpler_fallback": "swift-functions"
  },
  {
    "id": "swift-enums",
    "title_en": "Enumerations",
    "title_ko": "열거형 (enum)",
    "level": "basic",
    "category": "types",
    "order": 14,
    "tip_ko": "연관값(associated value)을 쓰면 각 케이스에 추가 데이터를 붙일 수 있어요",
    "tip_en": "Use associated values to attach extra data to each case",
    "teaching_hints_ko": {
      "what": "관련된 값들을 하나의 타입으로 그룹화. 각 값은 case로 정의",
      "why": "유효한 값만 사용하도록 강제해서 버그를 줄여줌",
      "how": "enum Direction {\n    case north, south, east, west\n}\nvar heading = Direction.north\n\nenum Result {\n    case success(String)\n    case failure(Error)\n}",
      "watchOut": "switch로 처리할 때 모든 case를 빠짐없이 다뤄야 함"
    },
    "teaching_hints_en": {
      "what": "Groups related values into a single type with defined cases",
      "why": "Enforces valid values at compile time, reducing bugs",
      "how": "enum Direction {\n    case north, south, east, west\n}\nvar heading = Direction.north\n\nenum Result {\n    case success(String)\n    case failure(Error)\n}",
      "watchOut": "Switch over an enum must handle every case or include default"
    },
    "analogies_ko": [
      "카드 뽑기: 정해진 카드(케이스) 중에서만 뽑을 수 있음"
    ],
    "analogies_en": [
      "A deck of cards with only specific suits — no inventing new ones"
    ],
    "simpler_fallback": "swift-if-else"
  },
  {
    "id": "swift-structs-classes",
    "title_en": "Structs and Classes",
    "title_ko": "구조체와 클래스 (struct, class)",
    "level": "basic",
    "category": "oop",
    "order": 15,
    "tip_ko": "기본적으로 struct를 쓰고, 상속이나 참조 공유가 필요할 때만 class를 써요",
    "tip_en": "Default to struct; use class only when you need inheritance or shared references",
    "teaching_hints_ko": {
      "what": "데이터와 동작을 묶어 사용자 정의 타입을 만드는 도구. struct는 값 타입, class는 참조 타입",
      "why": "현실 세계의 개념을 코드로 모델링할 때 필수",
      "how": "struct Point {\n    var x: Double\n    var y: Double\n}\n\nclass Vehicle {\n    var speed: Int = 0\n    func accelerate() { speed += 10 }\n}",
      "watchOut": "struct를 복사하면 독립적인 사본이 생기지만 class는 같은 객체를 공유"
    },
    "teaching_hints_en": {
      "what": "Custom types bundling data and behavior. struct is value type, class is reference type",
      "why": "Essential for modeling real-world concepts in code",
      "how": "struct Point {\n    var x: Double\n    var y: Double\n}\n\nclass Vehicle {\n    var speed: Int = 0\n    func accelerate() { speed += 10 }\n}",
      "watchOut": "Copying a struct creates an independent copy; copying a class shares the same instance"
    },
    "analogies_ko": [
      "struct는 종이 복사 — 각자 독립. class는 구글 문서 — 모두가 같은 걸 봄"
    ],
    "analogies_en": [
      "struct is photocopying a document; class is sharing a Google Doc"
    ],
    "simpler_fallback": "swift-functions"
  },
  {
    "id": "swift-properties",
    "title_en": "Properties",
    "title_ko": "프로퍼티 (Properties)",
    "level": "basic",
    "category": "oop",
    "order": 16,
    "tip_ko": "계산 프로퍼티(computed)로 매번 새로 계산되는 값을 깔끔하게 표현할 수 있어요",
    "tip_en": "Use computed properties for values derived from other properties",
    "teaching_hints_ko": {
      "what": "타입에 속한 값. 저장 프로퍼티(stored)와 계산 프로퍼티(computed)가 있음",
      "why": "데이터를 구조화하고 파생 값을 자동으로 계산하기 위해 사용",
      "how": "struct Circle {\n    var radius: Double\n    var area: Double {\n        return .pi * radius * radius\n    }\n}\nlet c = Circle(radius: 5)\nprint(c.area)",
      "watchOut": "계산 프로퍼티는 호출할 때마다 다시 계산되므로 비용이 클 수 있음"
    },
    "teaching_hints_en": {
      "what": "Values belonging to a type — stored properties hold data, computed properties calculate it",
      "why": "Structures data and auto-computes derived values",
      "how": "struct Circle {\n    var radius: Double\n    var area: Double {\n        return .pi * radius * radius\n    }\n}\nlet c = Circle(radius: 5)\nprint(c.area)",
      "watchOut": "Computed properties recalculate on every access, which can be expensive"
    },
    "analogies_ko": [
      "저장 프로퍼티는 서랍 속 물건, 계산 프로퍼티는 체중계 위 몸무게"
    ],
    "analogies_en": [
      "Stored property is a book on a shelf; computed property is a live stock ticker"
    ],
    "simpler_fallback": "swift-structs-classes"
  },
  {
    "id": "swift-methods",
    "title_en": "Methods",
    "title_ko": "메서드 (Methods)",
    "level": "basic",
    "category": "oop",
    "order": 17,
    "tip_ko": "struct에서 프로퍼티를 변경하는 메서드에는 mutating을 붙여야 해요",
    "tip_en": "Mark methods that modify struct properties with the mutating keyword",
    "teaching_hints_ko": {
      "what": "타입에 속한 함수. 인스턴스 메서드와 타입 메서드가 있음",
      "why": "데이터와 그 데이터를 다루는 동작을 함께 묶기 위해 필요",
      "how": "struct Counter {\n    var value = 0\n    mutating func increment() {\n        value += 1\n    }\n    static func zero() -> Counter {\n        return Counter()\n    }\n}",
      "watchOut": "struct의 인스턴스 메서드에서 프로퍼티를 바꾸려면 mutating 필수"
    },
    "teaching_hints_en": {
      "what": "Functions that belong to a type — instance methods and type (static) methods",
      "why": "Bundles behavior with the data it operates on",
      "how": "struct Counter {\n    var value = 0\n    mutating func increment() {\n        value += 1\n    }\n    static func zero() -> Counter {\n        return Counter()\n    }\n}",
      "watchOut": "Struct methods that modify properties must be marked mutating"
    },
    "analogies_ko": [
      "리모컨 버튼: TV(객체)에 속한 동작(채널 변경, 음량 조절)"
    ],
    "analogies_en": [
      "Remote control buttons: actions that belong to the TV object"
    ],
    "simpler_fallback": "swift-functions"
  },
  {
    "id": "swift-initializers",
    "title_en": "Initializers",
    "title_ko": "초기화 (init)",
    "level": "basic",
    "category": "oop",
    "order": 18,
    "tip_ko": "struct는 멤버와이즈 이니셜라이저를 자동으로 제공해요. 커스텀 init을 extension에 넣으면 자동 init도 유지돼요",
    "tip_en": "Structs get a free memberwise init. Put custom inits in an extension to keep it",
    "teaching_hints_ko": {
      "what": "인스턴스 생성 시 호출되는 특별한 메서드. init 키워드로 정의",
      "why": "인스턴스가 사용 가능한 상태로 만들어지도록 보장",
      "how": "struct User {\n    let name: String\n    var age: Int\n    init(name: String, age: Int = 0) {\n        self.name = name\n        self.age = age\n    }\n}",
      "watchOut": "class에서 모든 프로퍼티를 초기화하지 않으면 컴파일 에러"
    },
    "teaching_hints_en": {
      "what": "Special methods called when creating an instance. Defined with init",
      "why": "Ensures every instance starts in a valid, usable state",
      "how": "struct User {\n    let name: String\n    var age: Int\n    init(name: String, age: Int = 0) {\n        self.name = name\n        self.age = age\n    }\n}",
      "watchOut": "In a class, all stored properties must be initialized or the compiler errors"
    },
    "analogies_ko": [
      "공장 조립 라인: 부품을 다 끼워야 완성품이 나옴"
    ],
    "analogies_en": [
      "An assembly line: every part must be installed before the product is done"
    ],
    "simpler_fallback": "swift-structs-classes"
  },
  {
    "id": "swift-optional-chaining",
    "title_en": "Optional Chaining",
    "title_ko": "옵셔널 체이닝 (Optional Chaining)",
    "level": "basic",
    "category": "types",
    "order": 19,
    "tip_ko": "?.를 연쇄로 쓸 수 있어요. 중간에 nil이면 전체가 nil을 반환",
    "tip_en": "Chain multiple ?. calls — if any link is nil, the whole chain returns nil",
    "teaching_hints_ko": {
      "what": "옵셔널 값의 프로퍼티나 메서드에 ?.로 안전하게 접근하는 방법",
      "why": "중첩된 옵셔널을 간결하게 처리할 수 있음",
      "how": "struct Address {\n    var city: String\n}\nstruct Person {\n    var address: Address?\n}\nlet person = Person(address: nil)\nlet city = person.address?.city  // nil",
      "watchOut": "체이닝 결과는 항상 옵셔널. 최종 값을 쓰려면 언래핑 필요"
    },
    "teaching_hints_en": {
      "what": "Safely accessing properties and methods on optional values using ?.",
      "why": "Handles nested optionals concisely without force unwrapping",
      "how": "struct Address {\n    var city: String\n}\nstruct Person {\n    var address: Address?\n}\nlet person = Person(address: nil)\nlet city = person.address?.city  // nil",
      "watchOut": "The result of optional chaining is always optional — you still need to unwrap"
    },
    "analogies_ko": [
      "러시안 인형: 하나씩 열어보되 빈 칸이면 거기서 멈추는 것"
    ],
    "analogies_en": [
      "Opening nested Russian dolls — stop if any one is empty"
    ],
    "simpler_fallback": "swift-optionals"
  },
  {
    "id": "swift-guard-let",
    "title_en": "Guard Statements",
    "title_ko": "guard-let 조기 탈출",
    "level": "basic",
    "category": "control-flow",
    "order": 20,
    "tip_ko": "함수 초반에 guard로 유효성 검사를 몰아두면 나머지 코드가 깔끔해져요",
    "tip_en": "Put guard checks at the top of functions to keep the happy path clean",
    "teaching_hints_ko": {
      "what": "조건이 거짓이면 즉시 함수를 빠져나가는 조기 탈출문",
      "why": "유효하지 않은 상태를 빨리 걸러내서 코드 들여쓰기를 줄여줌",
      "how": "func process(name: String?) {\n    guard let name = name else {\n        print(\"No name\")\n        return\n    }\n    // name은 여기서 non-optional\n    print(\"Hello, \\(name)\")\n}",
      "watchOut": "guard의 else 블록에서 반드시 return, throw, break 등으로 빠져나가야 함"
    },
    "teaching_hints_en": {
      "what": "An early exit statement that leaves the scope when a condition fails",
      "why": "Filters invalid states early and reduces nesting for the happy path",
      "how": "func process(name: String?) {\n    guard let name = name else {\n        print(\"No name\")\n        return\n    }\n    // name is non-optional here\n    print(\"Hello, \\(name)\")\n}",
      "watchOut": "The else block must exit the scope with return, throw, break, etc."
    },
    "analogies_ko": [
      "공항 보안 검색: 통과 못 하면 탑승 자체가 불가"
    ],
    "analogies_en": [
      "Airport security: if you don't pass, you don't board the plane"
    ],
    "simpler_fallback": "swift-optionals"
  },
  {
    "id": "swift-map-filter-reduce",
    "title_en": "Map, Filter, Reduce",
    "title_ko": "고차함수 (map, filter, reduce)",
    "level": "basic",
    "category": "closures",
    "order": 21,
    "tip_ko": "체이닝으로 연결하면 데이터 변환 파이프라인을 만들 수 있어요",
    "tip_en": "Chain them together to build data transformation pipelines",
    "teaching_hints_ko": {
      "what": "컬렉션의 각 요소를 변환(map), 걸러내기(filter), 합치기(reduce)하는 함수",
      "why": "for 루프 없이 데이터를 선언적으로 처리할 수 있음",
      "how": "let nums = [1, 2, 3, 4, 5]\nlet doubled = nums.map { $0 * 2 }      // [2,4,6,8,10]\nlet evens = nums.filter { $0 % 2 == 0 } // [2,4]\nlet sum = nums.reduce(0, +)             // 15",
      "watchOut": "reduce의 초기값을 잘못 설정하면 예상과 다른 결과가 나옴"
    },
    "teaching_hints_en": {
      "what": "Higher-order functions to transform (map), select (filter), and combine (reduce) collection elements",
      "why": "Declarative data processing without explicit for loops",
      "how": "let nums = [1, 2, 3, 4, 5]\nlet doubled = nums.map { $0 * 2 }      // [2,4,6,8,10]\nlet evens = nums.filter { $0 % 2 == 0 } // [2,4]\nlet sum = nums.reduce(0, +)             // 15",
      "watchOut": "Wrong initial value in reduce gives unexpected results"
    },
    "analogies_ko": [
      "공장 라인: 원재료(map) → 품질 검수(filter) → 포장(reduce)"
    ],
    "analogies_en": [
      "Factory line: raw material (map) → quality check (filter) → packaging (reduce)"
    ],
    "simpler_fallback": "swift-closures"
  },
  {
    "id": "swift-extensions",
    "title_en": "Extensions",
    "title_ko": "확장 (Extensions)",
    "level": "basic",
    "category": "oop",
    "order": 22,
    "tip_ko": "기존 타입에 기능을 추가할 때 상속 대신 extension을 쓰면 깔끔해요",
    "tip_en": "Add functionality to existing types without subclassing using extensions",
    "teaching_hints_ko": {
      "what": "기존 타입에 새로운 메서드, 프로퍼티, 프로토콜 채택 등을 추가하는 기능",
      "why": "원본 소스 코드를 수정하지 않고도 타입을 확장 가능",
      "how": "extension Int {\n    var isEven: Bool {\n        return self % 2 == 0\n    }\n}\nprint(4.isEven)  // true",
      "watchOut": "extension에서는 저장 프로퍼티를 추가할 수 없음 (계산 프로퍼티만 가능)"
    },
    "teaching_hints_en": {
      "what": "Adding new methods, computed properties, or protocol conformances to existing types",
      "why": "Extends types without modifying their original source code",
      "how": "extension Int {\n    var isEven: Bool {\n        return self % 2 == 0\n    }\n}\nprint(4.isEven)  // true",
      "watchOut": "Extensions cannot add stored properties — only computed properties"
    },
    "analogies_ko": [
      "스마트폰에 케이스를 끼우는 것: 폰 자체를 바꾸지 않고 기능 추가"
    ],
    "analogies_en": [
      "Snapping a case on your phone — adding features without modifying internals"
    ],
    "simpler_fallback": "swift-structs-classes"
  },
  {
    "id": "swift-access-control",
    "title_en": "Access Control",
    "title_ko": "접근 제어 (Access Control)",
    "level": "basic",
    "category": "oop",
    "order": 23,
    "tip_ko": "public API만 열어두고 나머지는 private/internal로 숨기면 유지보수가 쉬워요",
    "tip_en": "Expose only the public API; keep everything else private or internal",
    "teaching_hints_ko": {
      "what": "코드의 접근 범위를 제한하는 키워드: open, public, internal, fileprivate, private",
      "why": "내부 구현을 숨기고 외부에 필요한 것만 노출하여 안전한 설계를 만듦",
      "how": "struct BankAccount {\n    private var balance: Double = 0\n    mutating func deposit(_ amount: Double) {\n        balance += amount\n    }\n    var currentBalance: Double { balance }\n}",
      "watchOut": "기본 접근 수준은 internal이라 같은 모듈에서는 접근 가능"
    },
    "teaching_hints_en": {
      "what": "Keywords that restrict visibility: open, public, internal, fileprivate, private",
      "why": "Hides implementation details and exposes only what's needed",
      "how": "struct BankAccount {\n    private var balance: Double = 0\n    mutating func deposit(_ amount: Double) {\n        balance += amount\n    }\n    var currentBalance: Double { balance }\n}",
      "watchOut": "The default access level is internal — accessible within the same module"
    },
    "analogies_ko": [
      "호텔 카드키: 투숙객은 자기 방만 열 수 있음"
    ],
    "analogies_en": [
      "Hotel key card: guests can only open their own room"
    ],
    "simpler_fallback": "swift-structs-classes"
  },
  {
    "id": "swift-type-casting",
    "title_en": "Type Casting",
    "title_ko": "타입 캐스팅 (is, as)",
    "level": "basic",
    "category": "types",
    "order": 24,
    "tip_ko": "as?로 안전하게 캐스팅하고, as!는 확실할 때만 써요",
    "tip_en": "Use as? for safe casting; reserve as! for cases you're certain about",
    "teaching_hints_ko": {
      "what": "인스턴스의 타입을 확인(is)하거나 다른 타입으로 변환(as)하는 연산",
      "why": "상속 관계의 타입이나 Any 타입을 구체적으로 다룰 때 필요",
      "how": "class Animal {}\nclass Dog: Animal { func bark() {} }\nlet pet: Animal = Dog()\nif let dog = pet as? Dog {\n    dog.bark()\n}\nprint(pet is Dog)  // true",
      "watchOut": "as!로 캐스팅 실패 시 런타임 크래시 발생"
    },
    "teaching_hints_en": {
      "what": "Checking (is) or converting (as) an instance's type at runtime",
      "why": "Needed when working with inheritance hierarchies or Any types",
      "how": "class Animal {}\nclass Dog: Animal { func bark() {} }\nlet pet: Animal = Dog()\nif let dog = pet as? Dog {\n    dog.bark()\n}\nprint(pet is Dog)  // true",
      "watchOut": "as! crashes at runtime if the cast fails"
    },
    "analogies_ko": [
      "우체국에서 소포를 열어 안에 뭐가 들었는지 확인하는 것"
    ],
    "analogies_en": [
      "Opening a package at the post office to check what's inside"
    ],
    "simpler_fallback": "swift-structs-classes"
  },
  {
    "id": "swift-subscripts",
    "title_en": "Subscripts",
    "title_ko": "서브스크립트 (Subscripts)",
    "level": "basic",
    "category": "oop",
    "order": 25,
    "tip_ko": "커스텀 컬렉션을 만들 때 subscript를 정의하면 []로 접근할 수 있어요",
    "tip_en": "Define subscripts on custom types to enable bracket [] access",
    "teaching_hints_ko": {
      "what": "[] 문법으로 타입의 요소에 접근하는 단축키. subscript 키워드로 정의",
      "why": "배열이나 딕셔너리처럼 인덱스로 접근하는 커스텀 타입을 만들 수 있음",
      "how": "struct Matrix {\n    let rows: Int, columns: Int\n    var grid: [Double]\n    subscript(row: Int, col: Int) -> Double {\n        get { grid[row * columns + col] }\n        set { grid[row * columns + col] = newValue }\n    }\n}",
      "watchOut": "subscript에 유효하지 않은 인덱스가 들어오면 크래시할 수 있으므로 범위 검사 필요"
    },
    "teaching_hints_en": {
      "what": "Shortcuts to access elements using [] syntax. Defined with subscript keyword",
      "why": "Lets custom types use bracket notation like arrays and dictionaries",
      "how": "struct Matrix {\n    let rows: Int, columns: Int\n    var grid: [Double]\n    subscript(row: Int, col: Int) -> Double {\n        get { grid[row * columns + col] }\n        set { grid[row * columns + col] = newValue }\n    }\n}",
      "watchOut": "Invalid indices can crash — add bounds checking in your subscript"
    },
    "analogies_ko": [
      "도서관 서가 번호로 책을 찾는 것"
    ],
    "analogies_en": [
      "Finding a book by its shelf and position number in a library"
    ],
    "simpler_fallback": "swift-arrays"
  },
  {
    "id": "swift-protocols",
    "title_en": "Protocols",
    "title_ko": "프로토콜 (Protocol)",
    "level": "intermediate",
    "category": "protocols",
    "order": 26,
    "tip_ko": "프로토콜로 인터페이스를 먼저 정의하고 나중에 구현하면 테스트하기 쉬워져요",
    "tip_en": "Define the interface with a protocol first — it makes testing easier",
    "teaching_hints_ko": {
      "what": "타입이 반드시 구현해야 할 메서드와 프로퍼티의 청사진",
      "why": "서로 다른 타입이 같은 인터페이스를 공유하게 만들어 유연한 설계 가능",
      "how": "protocol Drawable {\n    func draw()\n}\nstruct Circle: Drawable {\n    func draw() { print(\"Drawing circle\") }\n}\nstruct Square: Drawable {\n    func draw() { print(\"Drawing square\") }\n}",
      "watchOut": "프로토콜의 모든 요구사항을 구현하지 않으면 컴파일 에러"
    },
    "teaching_hints_en": {
      "what": "A blueprint defining methods and properties that conforming types must implement",
      "why": "Enables different types to share the same interface for flexible design",
      "how": "protocol Drawable {\n    func draw()\n}\nstruct Circle: Drawable {\n    func draw() { print(\"Drawing circle\") }\n}\nstruct Square: Drawable {\n    func draw() { print(\"Drawing square\") }\n}",
      "watchOut": "Failing to implement all protocol requirements causes a compile error"
    },
    "analogies_ko": [
      "채용 공고: 자격 요건을 적어놓으면 지원자가 맞춰서 준비"
    ],
    "analogies_en": [
      "A job listing: defines requirements that applicants must fulfill"
    ],
    "simpler_fallback": "swift-structs-classes"
  },
  {
    "id": "swift-error-handling",
    "title_en": "Error Handling",
    "title_ko": "에러 처리 (do-try-catch)",
    "level": "intermediate",
    "category": "error-handling",
    "order": 27,
    "tip_ko": "에러 타입을 enum으로 만들면 케이스별로 정확하게 처리할 수 있어요",
    "tip_en": "Model errors as enums for precise case-by-case handling",
    "teaching_hints_ko": {
      "what": "실행 중 발생하는 에러를 던지고(throw), 잡아서(catch) 처리하는 구조",
      "why": "예상 가능한 실패를 안전하게 처리하여 앱이 죽지 않게 함",
      "how": "enum LoginError: Error {\n    case wrongPassword\n    case userNotFound\n}\nfunc login(pw: String) throws {\n    guard pw == \"1234\" else { throw LoginError.wrongPassword }\n}\ndo {\n    try login(pw: \"wrong\")\n} catch {\n    print(error)\n}",
      "watchOut": "try? 는 에러를 무시하고 nil로 바꾸므로 중요한 에러에는 do-catch 사용"
    },
    "teaching_hints_en": {
      "what": "Throwing and catching errors using do-try-catch",
      "why": "Safely handles expected failures so the app doesn't crash",
      "how": "enum LoginError: Error {\n    case wrongPassword\n    case userNotFound\n}\nfunc login(pw: String) throws {\n    guard pw == \"1234\" else { throw LoginError.wrongPassword }\n}\ndo {\n    try login(pw: \"wrong\")\n} catch {\n    print(error)\n}",
      "watchOut": "try? silently converts errors to nil — use do-catch for important errors"
    },
    "analogies_ko": [
      "야구에서 공을 던지고(throw) 포수가 받는(catch) 것"
    ],
    "analogies_en": [
      "A pitcher throws (throw) and the catcher catches (catch) in baseball"
    ],
    "simpler_fallback": "swift-enums"
  },
  {
    "id": "swift-generics",
    "title_en": "Generics",
    "title_ko": "제네릭 (Generics)",
    "level": "intermediate",
    "category": "generics",
    "order": 28,
    "tip_ko": "where 절로 제네릭 타입에 제약을 걸면 더 안전하고 유용한 코드를 쓸 수 있어요",
    "tip_en": "Use where clauses to constrain generic types for safer, more useful code",
    "teaching_hints_ko": {
      "what": "타입을 파라미터로 받아 여러 타입에 동작하는 범용 코드를 작성하는 방법",
      "why": "중복 없이 타입 안전한 재사용 가능한 코드를 만들 수 있음",
      "how": "func swapValues<T>(_ a: inout T, _ b: inout T) {\n    let temp = a\n    a = b\n    b = temp\n}\nstruct Stack<Element> {\n    var items: [Element] = []\n    mutating func push(_ item: Element) { items.append(item) }\n    mutating func pop() -> Element? { items.popLast() }\n}",
      "watchOut": "제약 없는 제네릭은 == 비교 등을 못 함. Equatable 제약 추가 필요"
    },
    "teaching_hints_en": {
      "what": "Writing code that works with any type using type parameters",
      "why": "Creates reusable, type-safe code without duplication",
      "how": "func swapValues<T>(_ a: inout T, _ b: inout T) {\n    let temp = a\n    a = b\n    b = temp\n}\nstruct Stack<Element> {\n    var items: [Element] = []\n    mutating func push(_ item: Element) { items.append(item) }\n    mutating func pop() -> Element? { items.popLast() }\n}",
      "watchOut": "Unconstrained generics can't use == — add Equatable constraint when needed"
    },
    "analogies_ko": [
      "만능 그릇: 어떤 재료든 담을 수 있지만 한번에 한 종류만"
    ],
    "analogies_en": [
      "A universal container: holds any type, but only one type at a time"
    ],
    "simpler_fallback": "swift-protocols"
  },
  {
    "id": "swift-swiftui-state",
    "title_en": "SwiftUI State Management",
    "title_ko": "SwiftUI 상태 관리 (@State)",
    "level": "intermediate",
    "category": "swiftui",
    "order": 29,
    "tip_ko": "@State는 해당 뷰 내부에서만 쓰고, 외부에서 받을 땐 @Binding을 써요",
    "tip_en": "Use @State for local view state and @Binding when passing state to child views",
    "teaching_hints_ko": {
      "what": "@State로 뷰의 로컬 상태를 선언하면 값이 바뀔 때 UI가 자동 업데이트",
      "why": "SwiftUI의 선언적 UI는 상태 변화를 감지해야 화면을 다시 그릴 수 있음",
      "how": "struct CounterView: View {\n    @State private var count = 0\n    var body: some View {\n        Button(\"Count: \\(count)\") {\n            count += 1\n        }\n    }\n}",
      "watchOut": "@State는 반드시 private으로 선언. 외부에서 직접 접근하면 안 됨"
    },
    "teaching_hints_en": {
      "what": "@State declares local view state — changes automatically update the UI",
      "why": "SwiftUI's declarative UI needs to detect state changes to re-render",
      "how": "struct CounterView: View {\n    @State private var count = 0\n    var body: some View {\n        Button(\"Count: \\(count)\") {\n            count += 1\n        }\n    }\n}",
      "watchOut": "@State should always be private — never expose it to parent views"
    },
    "analogies_ko": [
      "온도 조절기: 온도(상태)가 바뀌면 보일러(UI)가 자동으로 반응"
    ],
    "analogies_en": [
      "A thermostat: when the temperature (state) changes, the heater (UI) reacts"
    ],
    "simpler_fallback": "swift-structs-classes"
  },
  {
    "id": "swift-swiftui-lists",
    "title_en": "SwiftUI Lists and ForEach",
    "title_ko": "SwiftUI 리스트 (List, ForEach)",
    "level": "intermediate",
    "category": "swiftui",
    "order": 30,
    "tip_ko": "Identifiable 프로토콜을 채택하면 id 파라미터를 생략할 수 있어요",
    "tip_en": "Conform to Identifiable to skip the id parameter in ForEach",
    "teaching_hints_ko": {
      "what": "스크롤 가능한 리스트를 만드는 List와 반복 렌더링하는 ForEach",
      "why": "데이터 목록을 화면에 보여주는 가장 기본적인 SwiftUI 패턴",
      "how": "struct Item: Identifiable {\n    let id = UUID()\n    let name: String\n}\nstruct ListView: View {\n    let items = [Item(name: \"A\"), Item(name: \"B\")]\n    var body: some View {\n        List(items) { item in\n            Text(item.name)\n        }\n    }\n}",
      "watchOut": "ForEach에 사용되는 데이터는 반드시 고유 id를 가져야 함"
    },
    "teaching_hints_en": {
      "what": "List creates scrollable lists; ForEach renders items from a collection",
      "why": "The fundamental SwiftUI pattern for displaying data collections",
      "how": "struct Item: Identifiable {\n    let id = UUID()\n    let name: String\n}\nstruct ListView: View {\n    let items = [Item(name: \"A\"), Item(name: \"B\")]\n    var body: some View {\n        List(items) { item in\n            Text(item.name)\n        }\n    }\n}",
      "watchOut": "Data in ForEach must have unique identifiers or you get undefined behavior"
    },
    "analogies_ko": [
      "메뉴판: 음식 목록을 나열하고 각 항목을 같은 형식으로 보여주는 것"
    ],
    "analogies_en": [
      "A restaurant menu: listing items in a consistent, scrollable format"
    ],
    "simpler_fallback": "swift-swiftui-state"
  },
  {
    "id": "swift-swiftui-navigation",
    "title_en": "SwiftUI Navigation",
    "title_ko": "SwiftUI 네비게이션 (NavigationStack)",
    "level": "intermediate",
    "category": "swiftui",
    "order": 31,
    "tip_ko": "NavigationStack + navigationDestination(for:)을 쓰면 타입 기반 네비게이션이 가능해요",
    "tip_en": "Use NavigationStack + navigationDestination(for:) for type-safe navigation",
    "teaching_hints_ko": {
      "what": "화면 간 이동을 관리하는 NavigationStack과 NavigationLink",
      "why": "앱에서 여러 화면을 오가는 흐름을 구현하기 위해 필수",
      "how": "struct ContentView: View {\n    var body: some View {\n        NavigationStack {\n            NavigationLink(\"Detail\") {\n                Text(\"Detail View\")\n            }\n            .navigationTitle(\"Home\")\n        }\n    }\n}",
      "watchOut": "NavigationView는 deprecated — NavigationStack을 사용할 것"
    },
    "teaching_hints_en": {
      "what": "NavigationStack and NavigationLink manage screen-to-screen transitions",
      "why": "Essential for building multi-screen app flows",
      "how": "struct ContentView: View {\n    var body: some View {\n        NavigationStack {\n            NavigationLink(\"Detail\") {\n                Text(\"Detail View\")\n            }\n            .navigationTitle(\"Home\")\n        }\n    }\n}",
      "watchOut": "NavigationView is deprecated — use NavigationStack instead"
    },
    "analogies_ko": [
      "책의 목차에서 원하는 챕터를 누르면 해당 페이지로 이동"
    ],
    "analogies_en": [
      "A table of contents: tap a chapter to jump to that page"
    ],
    "simpler_fallback": "swift-swiftui-state"
  },
  {
    "id": "swift-codable",
    "title_en": "Codable (JSON Encoding/Decoding)",
    "title_ko": "Codable (JSON 인코딩/디코딩)",
    "level": "intermediate",
    "category": "protocols",
    "order": 32,
    "tip_ko": "서버의 키 이름이 다를 때 CodingKeys enum으로 매핑할 수 있어요",
    "tip_en": "Use CodingKeys enum to map different JSON key names to your properties",
    "teaching_hints_ko": {
      "what": "JSON 등 외부 형식과 Swift 타입을 자동 변환하는 프로토콜",
      "why": "서버 API 통신에서 JSON 파싱은 거의 모든 앱에 필요",
      "how": "struct User: Codable {\n    let name: String\n    let age: Int\n}\nlet json = \"{\\\"name\\\":\\\"Kim\\\",\\\"age\\\":30}\".data(using: .utf8)!\nlet user = try JSONDecoder().decode(User.self, from: json)\nprint(user.name)",
      "watchOut": "JSON 키와 프로퍼티 이름이 다르면 CodingKeys를 정의해야 함"
    },
    "teaching_hints_en": {
      "what": "A protocol for automatic conversion between Swift types and external formats like JSON",
      "why": "JSON parsing is needed in nearly every app that communicates with a server",
      "how": "struct User: Codable {\n    let name: String\n    let age: Int\n}\nlet json = \"{\\\"name\\\":\\\"Kim\\\",\\\"age\\\":30}\".data(using: .utf8)!\nlet user = try JSONDecoder().decode(User.self, from: json)\nprint(user.name)",
      "watchOut": "Mismatched JSON keys and property names require custom CodingKeys"
    },
    "analogies_ko": [
      "번역기: Swift 언어와 JSON 언어 사이를 자동 통역"
    ],
    "analogies_en": [
      "A translator automatically converting between Swift and JSON languages"
    ],
    "simpler_fallback": "swift-protocols"
  },
  {
    "id": "swift-result-type",
    "title_en": "Result Type",
    "title_ko": "Result 타입",
    "level": "intermediate",
    "category": "error-handling",
    "order": 33,
    "tip_ko": "비동기 콜백에서는 throws 대신 Result를 쓰면 에러를 깔끔하게 전달할 수 있어요",
    "tip_en": "Use Result in async callbacks where throws isn't available",
    "teaching_hints_ko": {
      "what": "성공(.success)과 실패(.failure)를 하나의 타입으로 표현하는 제네릭 enum",
      "why": "비동기 작업의 결과를 명확하게 전달할 수 있음",
      "how": "enum NetworkError: Error { case timeout }\nfunc fetch(completion: (Result<String, NetworkError>) -> Void) {\n    completion(.success(\"data\"))\n}\nfetch { result in\n    switch result {\n    case .success(let data): print(data)\n    case .failure(let error): print(error)\n    }\n}",
      "watchOut": "async/await 환경에서는 throws가 더 자연스러울 수 있음"
    },
    "teaching_hints_en": {
      "what": "A generic enum representing either success or failure",
      "why": "Clearly communicates the outcome of operations, especially async ones",
      "how": "enum NetworkError: Error { case timeout }\nfunc fetch(completion: (Result<String, NetworkError>) -> Void) {\n    completion(.success(\"data\"))\n}\nfetch { result in\n    switch result {\n    case .success(let data): print(data)\n    case .failure(let error): print(error)\n    }\n}",
      "watchOut": "In async/await contexts, throws may be more natural than Result"
    },
    "analogies_ko": [
      "시험 결과 봉투: 합격(success) 또는 불합격(failure) 통지서가 들어 있음"
    ],
    "analogies_en": [
      "An exam results envelope: contains either a pass or fail notice"
    ],
    "simpler_fallback": "swift-error-handling"
  },
  {
    "id": "swift-keypaths",
    "title_en": "Key Paths",
    "title_ko": "키 패스 (Key Paths)",
    "level": "intermediate",
    "category": "types",
    "order": 34,
    "tip_ko": "키 패스를 map에 넘기면 클로저 없이 프로퍼티를 추출할 수 있어요",
    "tip_en": "Pass key paths to map for closure-free property extraction",
    "teaching_hints_ko": {
      "what": "프로퍼티에 대한 참조를 \\ 문법으로 만드는 것. 나중에 값을 읽거나 쓸 수 있음",
      "why": "프로퍼티 접근을 변수처럼 저장하고 전달할 수 있어 유연한 코드 가능",
      "how": "struct Person {\n    var name: String\n    var age: Int\n}\nlet people = [Person(name: \"A\", age: 20), Person(name: \"B\", age: 30)]\nlet names = people.map(\\.name)  // [\"A\", \"B\"]\nlet sorted = people.sorted(by: \\.age)",
      "watchOut": "WritableKeyPath와 KeyPath를 구분해야 함. 읽기 전용은 값 변경 불가"
    },
    "teaching_hints_en": {
      "what": "References to properties using \\ syntax, allowing deferred read/write",
      "why": "Store and pass property access like a variable for flexible code",
      "how": "struct Person {\n    var name: String\n    var age: Int\n}\nlet people = [Person(name: \"A\", age: 20), Person(name: \"B\", age: 30)]\nlet names = people.map(\\.name)  // [\"A\", \"B\"]\nlet sorted = people.sorted(by: \\.age)",
      "watchOut": "Distinguish WritableKeyPath from KeyPath — read-only paths can't modify values"
    },
    "analogies_ko": [
      "GPS 좌표: 목적지(프로퍼티)까지의 경로를 저장해두는 것"
    ],
    "analogies_en": [
      "A GPS waypoint: saves the route to a property so you can visit it later"
    ],
    "simpler_fallback": "swift-properties"
  },
  {
    "id": "swift-property-wrappers",
    "title_en": "Property Wrappers",
    "title_ko": "프로퍼티 래퍼 (@propertyWrapper)",
    "level": "intermediate",
    "category": "types",
    "order": 35,
    "tip_ko": "@State, @Binding, @Published 모두 프로퍼티 래퍼예요. 원리를 알면 SwiftUI가 쉬워져요",
    "tip_en": "@State, @Binding, @Published are all property wrappers — understanding them unlocks SwiftUI",
    "teaching_hints_ko": {
      "what": "프로퍼티의 저장/읽기 동작을 커스텀하는 재사용 가능한 래퍼",
      "why": "반복되는 프로퍼티 로직(검증, 변환 등)을 한 번만 정의하고 재사용 가능",
      "how": "@propertyWrapper\nstruct Clamped {\n    var wrappedValue: Int {\n        didSet { wrappedValue = min(max(wrappedValue, 0), 100) }\n    }\n    init(wrappedValue: Int) {\n        self.wrappedValue = min(max(wrappedValue, 0), 100)\n    }\n}\nstruct Settings {\n    @Clamped var volume: Int = 50\n}",
      "watchOut": "projectedValue($로 접근)와 wrappedValue를 혼동하지 않도록 주의"
    },
    "teaching_hints_en": {
      "what": "Reusable wrappers that customize how a property is stored and accessed",
      "why": "Define repetitive property logic (validation, transformation) once and reuse it",
      "how": "@propertyWrapper\nstruct Clamped {\n    var wrappedValue: Int {\n        didSet { wrappedValue = min(max(wrappedValue, 0), 100) }\n    }\n    init(wrappedValue: Int) {\n        self.wrappedValue = min(max(wrappedValue, 0), 100)\n    }\n}\nstruct Settings {\n    @Clamped var volume: Int = 50\n}",
      "watchOut": "Don't confuse projectedValue (accessed with $) and wrappedValue"
    },
    "analogies_ko": [
      "선물 포장: 안의 물건(값)은 같지만 포장(래퍼)이 추가 기능을 제공"
    ],
    "analogies_en": [
      "Gift wrapping: the item inside is the same, but the wrapper adds features"
    ],
    "simpler_fallback": "swift-properties"
  },
  {
    "id": "swift-opaque-types",
    "title_en": "Opaque Types (some)",
    "title_ko": "불투명 타입 (some)",
    "level": "intermediate",
    "category": "generics",
    "order": 36,
    "tip_ko": "SwiftUI에서 body의 some View가 바로 불투명 타입이에요",
    "tip_en": "SwiftUI's some View in the body property is an opaque type",
    "teaching_hints_ko": {
      "what": "구체적 타입을 숨기고 프로토콜만 노출하는 some 키워드",
      "why": "API를 단순하게 유지하면서 컴파일러가 구체 타입을 추적할 수 있게 함",
      "how": "func makeShape() -> some Shape {\n    Circle()\n}\n// 호출자는 Shape만 알지만 컴파일러는 Circle임을 앎",
      "watchOut": "같은 some 반환 타입에서 조건에 따라 다른 구체 타입을 반환하면 에러"
    },
    "teaching_hints_en": {
      "what": "The some keyword hides the concrete type while exposing only the protocol",
      "why": "Keeps APIs simple while letting the compiler track the actual type",
      "how": "func makeShape() -> some Shape {\n    Circle()\n}\n// The caller sees Shape, but the compiler knows it's Circle",
      "watchOut": "Returning different concrete types from the same some return type is an error"
    },
    "analogies_ko": [
      "베일에 가린 요리사: 어떤 요리사인지 모르지만 요리는 확실히 나옴"
    ],
    "analogies_en": [
      "A masked chef: you don't know who's cooking, but the dish is guaranteed"
    ],
    "simpler_fallback": "swift-generics"
  },
  {
    "id": "swift-swiftui-environment",
    "title_en": "SwiftUI Environment",
    "title_ko": "SwiftUI 환경 (@Environment)",
    "level": "intermediate",
    "category": "swiftui",
    "order": 37,
    "tip_ko": "@EnvironmentObject는 뷰 계층 어디서든 접근 가능하므로 전역 상태 공유에 좋아요",
    "tip_en": "@EnvironmentObject is accessible from any view in the hierarchy — great for shared state",
    "teaching_hints_ko": {
      "what": "뷰 계층을 통해 데이터를 전달하는 @Environment와 @EnvironmentObject",
      "why": "부모에서 자식까지 프로퍼티를 일일이 넘기지 않고 공유 가능",
      "how": "struct ChildView: View {\n    @Environment(\\.colorScheme) var colorScheme\n    var body: some View {\n        Text(colorScheme == .dark ? \"Dark\" : \"Light\")\n    }\n}",
      "watchOut": "@EnvironmentObject를 주입하지 않고 접근하면 런타임 크래시"
    },
    "teaching_hints_en": {
      "what": "@Environment and @EnvironmentObject pass data through the view hierarchy",
      "why": "Share data without manually passing properties through every view",
      "how": "struct ChildView: View {\n    @Environment(\\.colorScheme) var colorScheme\n    var body: some View {\n        Text(colorScheme == .dark ? \"Dark\" : \"Light\")\n    }\n}",
      "watchOut": "Accessing @EnvironmentObject without injecting it causes a runtime crash"
    },
    "analogies_ko": [
      "학교 방송: 교장이 한 번 말하면 모든 교실에서 들을 수 있음"
    ],
    "analogies_en": [
      "School intercom: one announcement reaches every classroom"
    ],
    "simpler_fallback": "swift-swiftui-state"
  },
  {
    "id": "swift-combine-basics",
    "title_en": "Combine Basics",
    "title_ko": "Combine 기초 (Publisher, Subscriber)",
    "level": "intermediate",
    "category": "concurrency",
    "order": 38,
    "tip_ko": "AnyCancellable을 저장해두지 않으면 구독이 즉시 해제되니 주의해요",
    "tip_en": "Store AnyCancellable or the subscription is immediately cancelled",
    "teaching_hints_ko": {
      "what": "시간에 따라 변하는 값을 Publisher가 내보내고 Subscriber가 받는 반응형 프레임워크",
      "why": "비동기 이벤트 스트림(네트워크, UI 이벤트 등)을 선언적으로 처리 가능",
      "how": "import Combine\nlet publisher = [1, 2, 3].publisher\nlet cancellable = publisher\n    .map { $0 * 2 }\n    .sink { print($0) }  // 2, 4, 6",
      "watchOut": "cancellable을 변수에 저장하지 않으면 구독이 바로 끊어짐"
    },
    "teaching_hints_en": {
      "what": "A reactive framework where Publishers emit values over time and Subscribers receive them",
      "why": "Declaratively handles async event streams like network calls and UI events",
      "how": "import Combine\nlet publisher = [1, 2, 3].publisher\nlet cancellable = publisher\n    .map { $0 * 2 }\n    .sink { print($0) }  // 2, 4, 6",
      "watchOut": "Without storing the cancellable, the subscription is immediately deallocated"
    },
    "analogies_ko": [
      "유튜브 구독: 채널(Publisher)이 영상을 올리면 구독자(Subscriber)에게 알림"
    ],
    "analogies_en": [
      "YouTube subscription: the channel (Publisher) uploads and subscribers get notified"
    ],
    "simpler_fallback": "swift-closures"
  },
  {
    "id": "swift-async-await",
    "title_en": "Async/Await",
    "title_ko": "비동기 프로그래밍 (async/await)",
    "level": "advanced",
    "category": "concurrency",
    "order": 39,
    "tip_ko": "await 뒤에는 실행이 일시 중단될 수 있어요. 상태 변화에 주의하세요",
    "tip_en": "Execution can suspend at await points — be careful about state changes",
    "teaching_hints_ko": {
      "what": "비동기 작업을 동기 코드처럼 순차적으로 작성할 수 있게 해주는 문법",
      "why": "콜백 지옥 없이 네트워크 호출, 파일 I/O 등을 깔끔하게 처리",
      "how": "func fetchData() async throws -> String {\n    let (data, _) = try await URLSession.shared.data(from: url)\n    return String(data: data, encoding: .utf8) ?? \"\"\n}\nTask {\n    let result = try await fetchData()\n    print(result)\n}",
      "watchOut": "async 함수는 async 컨텍스트에서만 호출 가능. Task로 감싸야 할 수도 있음"
    },
    "teaching_hints_en": {
      "what": "Syntax for writing asynchronous code in a sequential, synchronous style",
      "why": "Eliminates callback hell for network calls, file I/O, and more",
      "how": "func fetchData() async throws -> String {\n    let (data, _) = try await URLSession.shared.data(from: url)\n    return String(data: data, encoding: .utf8) ?? \"\"\n}\nTask {\n    let result = try await fetchData()\n    print(result)\n}",
      "watchOut": "async functions can only be called from async contexts — wrap in Task if needed"
    },
    "analogies_ko": [
      "카페 주문: 주문(await) 후 진동벨이 울리면 커피를 받는 것"
    ],
    "analogies_en": [
      "Ordering coffee: you place the order (await) and pick it up when it's ready"
    ],
    "simpler_fallback": "swift-closures"
  },
  {
    "id": "swift-actors",
    "title_en": "Actors",
    "title_ko": "액터 (Actor)",
    "level": "advanced",
    "category": "concurrency",
    "order": 40,
    "tip_ko": "actor의 프로퍼티에 외부에서 접근할 때는 항상 await이 필요해요",
    "tip_en": "Accessing actor properties from outside always requires await",
    "teaching_hints_ko": {
      "what": "동시 접근으로부터 내부 상태를 자동으로 보호하는 참조 타입",
      "why": "데이터 레이스를 컴파일 타임에 방지하여 안전한 동시성 코드를 작성",
      "how": "actor BankAccount {\n    var balance: Double = 0\n    func deposit(_ amount: Double) {\n        balance += amount\n    }\n}\nlet account = BankAccount()\nTask {\n    await account.deposit(100)\n    print(await account.balance)\n}",
      "watchOut": "actor 내부에서 오래 걸리는 동기 작업을 하면 다른 접근이 블로킹됨"
    },
    "teaching_hints_en": {
      "what": "Reference types that automatically protect their internal state from concurrent access",
      "why": "Prevents data races at compile time for safe concurrent code",
      "how": "actor BankAccount {\n    var balance: Double = 0\n    func deposit(_ amount: Double) {\n        balance += amount\n    }\n}\nlet account = BankAccount()\nTask {\n    await account.deposit(100)\n    print(await account.balance)\n}",
      "watchOut": "Long synchronous work inside an actor blocks other callers"
    },
    "analogies_ko": [
      "은행 창구: 한 번에 한 고객만 처리해서 잔고 꼬임 방지"
    ],
    "analogies_en": [
      "A bank teller window: serves one customer at a time to prevent balance errors"
    ],
    "simpler_fallback": "swift-async-await"
  },
  {
    "id": "swift-protocol-extensions",
    "title_en": "Protocol Extensions",
    "title_ko": "프로토콜 확장 (Protocol Extensions)",
    "level": "advanced",
    "category": "protocols",
    "order": 41,
    "tip_ko": "프로토콜 확장에서 기본 구현을 제공하면 채택하는 타입이 일일이 구현하지 않아도 돼요",
    "tip_en": "Default implementations in protocol extensions save conforming types from boilerplate",
    "teaching_hints_ko": {
      "what": "프로토콜에 기본 구현을 추가하는 extension. 채택만 하면 기능을 얻음",
      "why": "공통 동작을 한 곳에서 정의하여 코드 중복을 제거",
      "how": "protocol Greetable {\n    var name: String { get }\n}\nextension Greetable {\n    func greet() -> String {\n        return \"Hello, \\(name)!\"\n    }\n}\nstruct User: Greetable {\n    let name: String\n}\nUser(name: \"Kim\").greet()  // \"Hello, Kim!\"",
      "watchOut": "프로토콜 요구사항이 아닌 메서드의 기본 구현은 정적 디스패치됨"
    },
    "teaching_hints_en": {
      "what": "Extensions on protocols that add default method implementations",
      "why": "Define common behavior once, eliminating duplication across conforming types",
      "how": "protocol Greetable {\n    var name: String { get }\n}\nextension Greetable {\n    func greet() -> String {\n        return \"Hello, \\(name)!\"\n    }\n}\nstruct User: Greetable {\n    let name: String\n}\nUser(name: \"Kim\").greet()  // \"Hello, Kim!\"",
      "watchOut": "Methods not in protocol requirements use static dispatch in extensions"
    },
    "analogies_ko": [
      "동아리 회칙에 기본 활동이 적혀 있어서 가입만 하면 참여 가능"
    ],
    "analogies_en": [
      "A club charter with default activities — join and you're automatically included"
    ],
    "simpler_fallback": "swift-protocols"
  },
  {
    "id": "swift-associated-types",
    "title_en": "Associated Types",
    "title_ko": "연관 타입 (Associated Types)",
    "level": "advanced",
    "category": "generics",
    "order": 42,
    "tip_ko": "associatedtype은 프로토콜의 제네릭이라고 생각하면 쉬워요",
    "tip_en": "Think of associatedtype as generics for protocols",
    "teaching_hints_ko": {
      "what": "프로토콜 내에서 사용될 타입의 플레이스홀더. associatedtype으로 선언",
      "why": "프로토콜을 제네릭하게 만들어 다양한 타입과 함께 동작하도록 함",
      "how": "protocol Container {\n    associatedtype Item\n    mutating func append(_ item: Item)\n    var count: Int { get }\n}\nstruct IntStack: Container {\n    var items: [Int] = []\n    mutating func append(_ item: Int) { items.append(item) }\n    var count: Int { items.count }\n}",
      "watchOut": "associatedtype이 있는 프로토콜은 변수 타입으로 직접 사용 불가 (some 또는 any 필요)"
    },
    "teaching_hints_en": {
      "what": "Type placeholders in protocols, declared with associatedtype",
      "why": "Makes protocols generic so they work with various concrete types",
      "how": "protocol Container {\n    associatedtype Item\n    mutating func append(_ item: Item)\n    var count: Int { get }\n}\nstruct IntStack: Container {\n    var items: [Int] = []\n    mutating func append(_ item: Int) { items.append(item) }\n    var count: Int { items.count }\n}",
      "watchOut": "Protocols with associated types can't be used as variable types directly (use some or any)"
    },
    "analogies_ko": [
      "빈칸 채우기 양식: 프로토콜이 '___타입'이라고 적어두면 채택자가 채움"
    ],
    "analogies_en": [
      "A fill-in-the-blank form: the protocol says 'type ___' and conformers fill it in"
    ],
    "simpler_fallback": "swift-protocols"
  },
  {
    "id": "swift-task-groups",
    "title_en": "Task Groups",
    "title_ko": "태스크 그룹 (TaskGroup)",
    "level": "advanced",
    "category": "concurrency",
    "order": 43,
    "tip_ko": "withTaskGroup에서 addTask로 추가한 작업들은 병렬로 실행돼요",
    "tip_en": "Tasks added with addTask inside withTaskGroup run in parallel",
    "teaching_hints_ko": {
      "what": "여러 비동기 작업을 동시에 실행하고 결과를 모아서 처리하는 구조",
      "why": "독립적인 작업을 병렬로 실행하여 전체 처리 시간을 단축",
      "how": "func fetchAll(ids: [Int]) async -> [String] {\n    await withTaskGroup(of: String.self) { group in\n        for id in ids {\n            group.addTask { await fetchItem(id: id) }\n        }\n        var results: [String] = []\n        for await result in group {\n            results.append(result)\n        }\n        return results\n    }\n}",
      "watchOut": "결과 순서가 보장되지 않으므로 순서가 중요하면 별도 처리 필요"
    },
    "teaching_hints_en": {
      "what": "Run multiple async tasks concurrently and collect their results",
      "why": "Reduces total execution time by running independent tasks in parallel",
      "how": "func fetchAll(ids: [Int]) async -> [String] {\n    await withTaskGroup(of: String.self) { group in\n        for id in ids {\n            group.addTask { await fetchItem(id: id) }\n        }\n        var results: [String] = []\n        for await result in group {\n            results.append(result)\n        }\n        return results\n    }\n}",
      "watchOut": "Results are not guaranteed to arrive in order — handle ordering separately"
    },
    "analogies_ko": [
      "단체 주문: 여러 음식을 동시에 주문하고 다 나오면 함께 먹기 시작"
    ],
    "analogies_en": [
      "Group ordering at a restaurant: order everything at once, eat when all dishes arrive"
    ],
    "simpler_fallback": "swift-async-await"
  },
  {
    "id": "swift-sendable",
    "title_en": "Sendable Protocol",
    "title_ko": "Sendable 프로토콜",
    "level": "advanced",
    "category": "concurrency",
    "order": 44,
    "tip_ko": "struct는 모든 프로퍼티가 Sendable이면 자동으로 Sendable이에요",
    "tip_en": "Structs automatically conform to Sendable if all their properties are Sendable",
    "teaching_hints_ko": {
      "what": "동시성 경계를 넘어 안전하게 전달할 수 있는 타입임을 표시하는 프로토콜",
      "why": "컴파일러가 데이터 레이스 위험을 검사하여 안전한 동시성 코드 보장",
      "how": "struct Point: Sendable {\n    let x: Double\n    let y: Double\n}\n// @Sendable 클로저\nlet task = Task { @Sendable in\n    let p = Point(x: 1, y: 2)\n    return p\n}",
      "watchOut": "class는 Sendable 준수가 어려움. final class + 불변 프로퍼티 필요"
    },
    "teaching_hints_en": {
      "what": "A protocol marking types safe to pass across concurrency boundaries",
      "why": "Lets the compiler check for data race risks in concurrent code",
      "how": "struct Point: Sendable {\n    let x: Double\n    let y: Double\n}\n// @Sendable closure\nlet task = Task { @Sendable in\n    let p = Point(x: 1, y: 2)\n    return p\n}",
      "watchOut": "Classes must be final with immutable properties to conform to Sendable"
    },
    "analogies_ko": [
      "우편으로 보낼 수 있는 물건: 배송(동시성 경계) 중에 변하지 않아야 안전"
    ],
    "analogies_en": [
      "Mailing a package: it must not change during transit across concurrency boundaries"
    ],
    "simpler_fallback": "swift-actors"
  },
  {
    "id": "swift-structured-concurrency",
    "title_en": "Structured Concurrency",
    "title_ko": "구조적 동시성 (Structured Concurrency)",
    "level": "advanced",
    "category": "concurrency",
    "order": 45,
    "tip_ko": "Task는 구조적, Task.detached는 비구조적. 가능하면 구조적 방식을 써요",
    "tip_en": "Prefer structured Task over Task.detached for automatic cancellation propagation",
    "teaching_hints_ko": {
      "what": "부모-자식 관계로 비동기 작업의 수명을 관리하는 동시성 모델",
      "why": "부모가 취소되면 자식도 자동 취소되어 리소스 누수 방지",
      "how": "func process() async {\n    async let a = fetchA()\n    async let b = fetchB()\n    let results = await (a, b)  // 병렬 실행, 구조적\n}\n// Task.detached는 비구조적 — 부모와 독립",
      "watchOut": "Task.detached는 부모의 취소/우선순위를 상속하지 않으므로 주의"
    },
    "teaching_hints_en": {
      "what": "A concurrency model where async tasks have parent-child lifetime relationships",
      "why": "Parent cancellation automatically cancels children, preventing resource leaks",
      "how": "func process() async {\n    async let a = fetchA()\n    async let b = fetchB()\n    let results = await (a, b)  // parallel, structured\n}\n// Task.detached is unstructured — independent of parent",
      "watchOut": "Task.detached doesn't inherit parent cancellation or priority"
    },
    "analogies_ko": [
      "회사 조직도: 팀장(부모)이 퇴사하면 팀원(자식) 업무도 정리"
    ],
    "analogies_en": [
      "An org chart: if the manager (parent) leaves, the team's (children) tasks wind down"
    ],
    "simpler_fallback": "swift-async-await"
  },
  {
    "id": "swift-swiftui-animation",
    "title_en": "SwiftUI Animations",
    "title_ko": "SwiftUI 애니메이션",
    "level": "advanced",
    "category": "swiftui",
    "order": 46,
    "tip_ko": "withAnimation 블록 안에서 상태를 바꾸면 변화가 자동으로 애니메이션돼요",
    "tip_en": "Change state inside withAnimation to automatically animate the transition",
    "teaching_hints_ko": {
      "what": "상태 변화에 따라 뷰 전환을 부드럽게 만드는 SwiftUI 애니메이션 시스템",
      "why": "사용자에게 시각적 피드백을 주어 더 좋은 UX를 제공",
      "how": "struct AnimView: View {\n    @State private var scale = 1.0\n    var body: some View {\n        Circle()\n            .scaleEffect(scale)\n            .onTapGesture {\n                withAnimation(.spring()) {\n                    scale = scale == 1.0 ? 1.5 : 1.0\n                }\n            }\n    }\n}",
      "watchOut": ".animation() 모디파이어는 deprecated — withAnimation 블록을 사용할 것"
    },
    "teaching_hints_en": {
      "what": "SwiftUI's animation system that smoothly transitions views when state changes",
      "why": "Provides visual feedback to users for a better experience",
      "how": "struct AnimView: View {\n    @State private var scale = 1.0\n    var body: some View {\n        Circle()\n            .scaleEffect(scale)\n            .onTapGesture {\n                withAnimation(.spring()) {\n                    scale = scale == 1.0 ? 1.5 : 1.0\n                }\n            }\n    }\n}",
      "watchOut": ".animation() modifier is deprecated — use withAnimation block instead"
    },
    "analogies_ko": [
      "슬로모션 카메라: 상태 변화를 천천히 보여주는 것"
    ],
    "analogies_en": [
      "Slow-motion camera: showing state changes in smooth motion"
    ],
    "simpler_fallback": "swift-swiftui-state"
  },
  {
    "id": "swift-swiftui-custom-layouts",
    "title_en": "SwiftUI Custom Layouts",
    "title_ko": "SwiftUI 커스텀 레이아웃",
    "level": "advanced",
    "category": "swiftui",
    "order": 47,
    "tip_ko": "Layout 프로토콜을 쓰면 HStack/VStack으로 불가능한 배치를 만들 수 있어요",
    "tip_en": "The Layout protocol enables arrangements impossible with HStack/VStack",
    "teaching_hints_ko": {
      "what": "Layout 프로토콜을 구현해 자식 뷰의 크기와 위치를 직접 제어",
      "why": "기본 HStack/VStack으로 표현할 수 없는 복잡한 레이아웃 구현 가능",
      "how": "struct RadialLayout: Layout {\n    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {\n        proposal.replacingUnspecifiedDimensions()\n    }\n    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {\n        let radius = min(bounds.width, bounds.height) / 2\n        for (i, subview) in subviews.enumerated() {\n            let angle = Angle.degrees(360.0 / Double(subviews.count) * Double(i))\n            let x = bounds.midX + radius * cos(angle.radians)\n            let y = bounds.midY + radius * sin(angle.radians)\n            subview.place(at: CGPoint(x: x, y: y), anchor: .center, proposal: .unspecified)\n        }\n    }\n}",
      "watchOut": "sizeThatFits와 placeSubviews 두 메서드를 모두 구현해야 함"
    },
    "teaching_hints_en": {
      "what": "Implementing the Layout protocol to control child view sizing and positioning",
      "why": "Enables complex layouts that HStack/VStack can't express",
      "how": "struct RadialLayout: Layout {\n    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {\n        proposal.replacingUnspecifiedDimensions()\n    }\n    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {\n        let radius = min(bounds.width, bounds.height) / 2\n        for (i, subview) in subviews.enumerated() {\n            let angle = Angle.degrees(360.0 / Double(subviews.count) * Double(i))\n            let x = bounds.midX + radius * cos(angle.radians)\n            let y = bounds.midY + radius * sin(angle.radians)\n            subview.place(at: CGPoint(x: x, y: y), anchor: .center, proposal: .unspecified)\n        }\n    }\n}",
      "watchOut": "You must implement both sizeThatFits and placeSubviews"
    },
    "analogies_ko": [
      "인테리어 디자이너: 가구(뷰)의 크기와 위치를 직접 설계"
    ],
    "analogies_en": [
      "An interior designer: deciding exactly where each piece of furniture goes"
    ],
    "simpler_fallback": "swift-swiftui-lists"
  },
  {
    "id": "swift-macro-basics",
    "title_en": "Swift Macros",
    "title_ko": "매크로 (Macros)",
    "level": "advanced",
    "category": "types",
    "order": 48,
    "tip_ko": "#Preview, @Observable 같은 것들이 모두 매크로예요. 반복 코드를 자동 생성해줘요",
    "tip_en": "#Preview and @Observable are macros — they auto-generate repetitive code",
    "teaching_hints_ko": {
      "what": "컴파일 시점에 코드를 자동 생성하거나 변환하는 Swift 5.9+ 기능",
      "why": "보일러플레이트 코드를 줄이고 컴파일 타임 안전성을 유지",
      "how": "// 사용 예 (built-in macro)\n@Observable\nclass UserModel {\n    var name = \"\"\n    var age = 0\n}\n// 커스텀 macro 정의는 Swift Package Plugin 필요",
      "watchOut": "매크로 정의에는 별도의 Swift Package 타깃이 필요하여 설정이 복잡"
    },
    "teaching_hints_en": {
      "what": "A Swift 5.9+ feature that generates or transforms code at compile time",
      "why": "Reduces boilerplate while maintaining compile-time safety",
      "how": "// Usage example (built-in macro)\n@Observable\nclass UserModel {\n    var name = \"\"\n    var age = 0\n}\n// Custom macro definitions require a Swift Package Plugin",
      "watchOut": "Defining custom macros requires a separate Swift Package target — setup is complex"
    },
    "analogies_ko": [
      "자동 번역기: 간단한 코드를 쓰면 컴파일러가 긴 코드로 펼쳐줌"
    ],
    "analogies_en": [
      "An auto-expander: you write shorthand, the compiler expands it into full code"
    ],
    "simpler_fallback": "swift-protocols"
  },
  {
    "id": "swift-memory-management",
    "title_en": "Memory Management (ARC)",
    "title_ko": "메모리 관리 (ARC)",
    "level": "advanced",
    "category": "oop",
    "order": 49,
    "tip_ko": "클로저에서 [weak self]를 쓰면 순환 참조를 예방할 수 있어요",
    "tip_en": "Use [weak self] in closures to prevent retain cycles",
    "teaching_hints_ko": {
      "what": "ARC(Automatic Reference Counting)가 class 인스턴스의 메모리를 자동 관리",
      "why": "메모리 누수 없이 효율적으로 메모리를 사용하기 위해 필수 개념",
      "how": "class Person {\n    let name: String\n    var pet: Pet?\n    init(name: String) { self.name = name }\n    deinit { print(\"\\(name) deallocated\") }\n}\nclass Pet {\n    weak var owner: Person?  // weak으로 순환 참조 방지\n}",
      "watchOut": "두 객체가 서로 strong 참조하면 영원히 해제되지 않는 순환 참조 발생"
    },
    "teaching_hints_en": {
      "what": "ARC (Automatic Reference Counting) automatically manages class instance memory",
      "why": "Essential for efficient memory usage without leaks",
      "how": "class Person {\n    let name: String\n    var pet: Pet?\n    init(name: String) { self.name = name }\n    deinit { print(\"\\(name) deallocated\") }\n}\nclass Pet {\n    weak var owner: Person?  // weak prevents retain cycle\n}",
      "watchOut": "Two objects with strong references to each other create a retain cycle — never deallocated"
    },
    "analogies_ko": [
      "도서관 대출: 빌린 사람이 0명이 되면 책이 서고로 돌아감(해제)"
    ],
    "analogies_en": [
      "Library book loans: when no one has it checked out (zero references), it returns to the shelf"
    ],
    "simpler_fallback": "swift-structs-classes"
  },
  {
    "id": "swift-existential-types",
    "title_en": "Existential Types (any)",
    "title_ko": "존재 타입 (any)",
    "level": "advanced",
    "category": "generics",
    "order": 50,
    "tip_ko": "성능이 중요하면 any 대신 some을 쓰세요. any는 런타임 오버헤드가 있어요",
    "tip_en": "Prefer some over any for performance — any has runtime overhead",
    "teaching_hints_ko": {
      "what": "프로토콜을 타입으로 사용할 때 any 키워드로 명시하는 Swift 5.6+ 문법",
      "why": "컴파일러가 존재 타입의 성능 비용을 개발자에게 명확히 알려줌",
      "how": "protocol Animal {\n    func speak()\n}\nfunc feedAll(animals: [any Animal]) {\n    for animal in animals {\n        animal.speak()\n    }\n}\n// some은 컴파일 타임 고정, any는 런타임 다형성",
      "watchOut": "any는 동적 디스패치라 some보다 느림. 꼭 필요할 때만 사용"
    },
    "teaching_hints_en": {
      "what": "Swift 5.6+ syntax requiring the any keyword when using protocols as types",
      "why": "Makes the performance cost of existential types explicit to developers",
      "how": "protocol Animal {\n    func speak()\n}\nfunc feedAll(animals: [any Animal]) {\n    for animal in animals {\n        animal.speak()\n    }\n}\n// some = compile-time fixed, any = runtime polymorphism",
      "watchOut": "any uses dynamic dispatch — slower than some. Use only when needed"
    },
    "analogies_ko": [
      "any는 '아무 동물이나 올 수 있는 동물원', some은 '특정 동물 전용 우리'"
    ],
    "analogies_en": [
      "any is a zoo that accepts any animal; some is a pen for one specific species"
    ],
    "simpler_fallback": "swift-protocols"
  }
];
