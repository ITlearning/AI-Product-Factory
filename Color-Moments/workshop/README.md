# 몽돌 단어 공방

단어 학생 모델을 만드는 Mac Studio용 도구 모음. 앱에 들어가는 것은 결과물(모델·표)뿐이다.

## 환경
- `~/.venvs/mongdol-word-lab` — Python 3.12
- torch 2.7.0 고정 (coremltools 9.0 이 시험한 최신). 올리지 않는다.
- 시험: `cd workshop && ~/.venvs/mongdol-word-lab/bin/python -m pytest -q`

## 자료 위치
`~/mongdol-word-lab` — 사진·사전 원자료·선생 답은 모두 여기에 둔다. 저장소에 올리지 않는다.

## 순서
1. 사진 고르기 `pick_train.py`
2. 추출 `extract/`
3. 선생 `teacher_expanded.py [--train]`
4. 학생 `student.py`
5. 판정 `judge.py`

물음 만들기는 `prompts.py [--train]`.

## 단어 목록 다시 만들기
`build_words.py` (Task 3에서 추가).

## 음력 표
`python lunar_table.py <words.json> ../Shared/Word/lunar-days.json` — 단어들의 `lunar` 조건에 나온 날만 2000~2060년 범위로 뽑는다.
앱과 `cond.py` 가 같은 표를 읽는다. 표가 없으면 `cond.py` 는 빈 표로 돌고 음력 조건은 모두 맞지 않는다. 윤달은 평달로 치지 않는다.
