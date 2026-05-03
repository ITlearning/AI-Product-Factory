fastlane documentation
----

> **셋업/사용 가이드는 [SETUP.md](./SETUP.md) 참고.**
> 이 파일은 fastlane이 만든 lane 목록 자동 생성본이다.

----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios beta

```sh
[bundle exec] fastlane ios beta
```

TestFlight에 새 베타 빌드 업로드 (build number 자동 +1)

### ios build_only

```sh
[bundle exec] fastlane ios build_only
```

로컬에서 release 빌드 검증만 (업로드 X)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
