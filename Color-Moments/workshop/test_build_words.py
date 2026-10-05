import build_words as b


def test_romanize_is_lowercase_letters():
    assert b.romanize("볕뉘") == "byeotnwi"
    assert b.romanize("해거름") == "haegeoreum"


def test_new_id_avoids_history():
    assert b.new_id("단잠", taken={"danjam"}) == "danjamb"


def test_meaning_cleanup():
    assert b.clean("저녁에 서쪽 하늘에 보이는 ‘금성03’을 이르는 말. 다른 뜻") == "저녁에 서쪽 하늘에 보이는 금성을 이르는 말"
    assert b.points_elsewhere("‘가을바람’의 준말")


def test_needs_rewrite_catches_digits_and_marks():
    assert b.needs_rewrite("늦은 겨울. 주로 음력 12월을 이른다")
    assert b.needs_rewrite("‘가을바람’의 준말")
    assert not b.needs_rewrite("겨울이 끝나 갈 무렵")


def test_conditions_the_app_does_not_know_are_dropped():
    assert b.app_conditions({"conditions": ["heavyRain", "hurricane"]}) == {"conditions": ["heavyRain"]}
    try:
        b.app_conditions({"word": "황사", "conditions": ["blowingDust"]})
        assert False, "조건을 다 지우면 단어가 넓어진다"
    except SystemExit:
        pass
