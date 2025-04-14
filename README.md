# 꺼내보기 (Unboxit)

저장만 하지 말고, 꺼내보자!

## 소개

꺼내보기는 다양한 플랫폼의 콘텐츠 링크를 한 곳에서 관리하고 다시 꺼내볼 수 있게 도와주는 정리형 북마크 앱입니다.

### 주요 기능

- 📱 **간편한 저장**: 공유하기 또는 URL 붙여넣기로 쉽게 저장
- 🔍 **자동 메타데이터 추출**: 제목, 설명, 썸네일 자동 파싱
- 🏷️ **태그 기반 정리**: 태그를 활용한 효율적인 콘텐츠 분류
- 🔎 **스마트 검색**: 제목, 태그, 메모 기반 검색
- 📋 **콘텐츠 미리보기**: 저장된 링크의 상세 정보 확인
- ✏️ **메모 기능**: 콘텐츠에 대한 개인 메모 추가

### 지원 플랫폼

- YouTube
- Instagram
- 네이버 블로그
- Velog
- 그 외 OG 태그가 있는 모든 웹사이트

## 기술 스택

- Frontend: Flutter
- Backend: Supabase
  - 인증: 이메일/비밀번호
  - 데이터베이스: PostgreSQL
- 상태 관리: Provider

## 설치 방법

1. 저장소 클론

```bash
git clone https://github.com/gobetterment/unboxit.git
```

2. 의존성 설치

```bash
flutter pub get
```

3. 환경 변수 설정

- `.env.example` 파일을 `.env`로 복사
- Supabase 프로젝트 설정에 맞게 값 수정

4. 실행

```bash
flutter run
```

## 라이선스

MIT License
