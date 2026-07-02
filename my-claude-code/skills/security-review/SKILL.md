---
name: security-review
description: 認証、ユーザー入力処理、シークレット管理、APIエンドポイント作成、機密データ処理時のセキュリティチェックリストとパターン集。
---

# Security Review Skill

コード変更がセキュリティベストプラクティスに従っているかを確認し、潜在的な脆弱性を特定する。

## 対象となる変更

- 認証・認可の実装
- ユーザー入力やファイルアップロードの処理
- 新規APIエンドポイントの作成
- シークレットや認証情報の扱い
- 機密データの保存・送信
- 外部APIとの連携
- メッセージブローカー経由のデータ処理

## セキュリティチェックリスト

### 1. シークレット管理

#### NEVER
```python
# ハードコードされたシークレット
api_key = "sk-proj-xxxxx"
db_password = "password123"
```

#### ALWAYS
```python
from pydantic_settings import BaseSettings

class Config(BaseSettings):
    api_key: str
    db_password: str

    model_config = SettingsConfigDict(env_file=".env")

config = Config()

# 起動時にバリデーション — 未設定なら即エラー
```

#### チェック項目
- [ ] ハードコードされたAPIキー、トークン、パスワードがない
- [ ] すべてのシークレットが環境変数経由
- [ ] `.env*` が `.gitignore` に含まれている
- [ ] gitの履歴にシークレットが残っていない

### 2. 入力バリデーション

#### リクエストボディのバリデーション
```python
from pydantic import BaseModel, Field

class CreateUserRequest(BaseModel):
    email: str = Field(..., pattern=r"^[\w\.-]+@[\w\.-]+\.\w+$")
    name: str = Field(..., min_length=1, max_length=100)
    age: int = Field(..., ge=0, le=150)

@router.post("/users")
async def create_user(request: CreateUserRequest):
    # Pydanticが自動バリデーション — 不正入力は422で拒否
    return await user_service.create(request)
```

#### クエリパラメータのバリデーション
```python
from uuid import UUID
from datetime import datetime

@router.get("/analytics")
async def get_analytics(
    region_id: UUID,
    start_time: datetime,
    end_time: datetime,
):
    # FastAPIの型ヒントで自動バリデーション
    if (end_time - start_time).total_seconds() > 86400:
        raise HTTPException(status_code=400, detail="期間は24時間以内")
    ...
```

#### ファイルアップロードのバリデーション
```python
from fastapi import UploadFile

ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/gif"}
MAX_FILE_SIZE = 5 * 1024 * 1024  # 5MB

async def validate_upload(file: UploadFile) -> None:
    if file.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(status_code=400, detail="許可されていないファイル形式")

    contents = await file.read()
    if len(contents) > MAX_FILE_SIZE:
        raise HTTPException(status_code=400, detail="ファイルサイズ上限超過（最大5MB）")
    await file.seek(0)
```

#### チェック項目
- [ ] すべてのユーザー入力がPydanticスキーマでバリデーション済み
- [ ] ファイルアップロードにサイズ・形式・拡張子の制限がある
- [ ] ユーザー入力がクエリに直接使われていない
- [ ] ホワイトリスト方式のバリデーション（ブラックリストではない）
- [ ] エラーメッセージが内部情報を漏洩していない

### 3. SQLインジェクション防止

#### NEVER — 文字列結合でSQL構築
```python
# 危険 — SQLインジェクション脆弱性
query = f"SELECT * FROM users WHERE email = '{user_email}'"
await db.execute(query)
```

#### ALWAYS — パラメータ化クエリ

##### SQLAlchemy / SQLModel
```python
from sqlmodel import select

# SQLModelのクエリビルダーを使用
statement = select(User).where(User.email == user_email)
result = await session.exec(statement)
```

##### REST API経由のDBクエリ
```python
# パラメータはURLエンコードで渡す — 文字列結合しない
def get_events(self, region_id: str, start_time: datetime) -> list[dict]:
    query = (
        "SELECT * FROM events "
        "WHERE region_id = $1 AND timestamp >= $2"
    )
    # REST APIではクエリ文字列にユーザー入力を直接埋め込まない
    params = {"query": query, "params": f"{region_id},{start_time.isoformat()}"}
    response = requests.get(f"{self.base_url}/exec", params=params)
    return response.json()
```

#### チェック項目
- [ ] すべてのDBクエリがパラメータ化またはORMのクエリビルダー経由
- [ ] SQLに文字列結合がない
- [ ] RAWクエリにユーザー入力が直接埋め込まれていない

### 4. 認証・認可

#### トークンの扱い
```python
# NEVER: レスポンスボディでトークンを返してlocalStorageに保存
# ALWAYS: httpOnlyクッキーを使用
from fastapi.responses import JSONResponse

def set_auth_cookie(response: JSONResponse, token: str) -> None:
    response.set_cookie(
        key="access_token",
        value=token,
        httponly=True,
        secure=True,
        samesite="strict",
        max_age=3600,
    )
```

#### 認可チェック
```python
from fastapi import Depends, HTTPException

async def require_admin(current_user: User = Depends(get_current_user)) -> User:
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="権限がありません")
    return current_user

@router.delete("/users/{user_id}")
async def delete_user(
    user_id: UUID,
    admin: User = Depends(require_admin),
):
    await user_service.delete(user_id)
```

#### Row Level Security（PostgreSQL）
```sql
-- RLSを有効化
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;

-- テナント単位のデータ分離
CREATE POLICY "tenant_isolation" ON devices
    USING (tenant_id = current_setting('app.current_tenant_id')::uuid);
```

#### チェック項目
- [ ] トークンがhttpOnlyクッキーに保存されている（localStorageではない）
- [ ] 機密操作の前に認可チェックがある
- [ ] ロールベースアクセス制御が実装されている
- [ ] マルチテナントのデータ分離が保証されている
- [ ] セッション管理が安全

### 5. XSS防止

#### HTMLのサニタイズ
```python
import bleach

# ユーザー提供のHTMLは必ずサニタイズ
def sanitize_html(raw_html: str) -> str:
    return bleach.clean(
        raw_html,
        tags=["b", "i", "em", "strong", "p"],
        attributes={},
        strip=True,
    )
```

#### Next.js（フロントエンド）
```typescript
// NEVER: dangerouslySetInnerHTMLにユーザー入力を直接渡さない
// ALWAYS: サニタイズしてから使用
import DOMPurify from 'isomorphic-dompurify'

function UserContent({ html }: { html: string }) {
  const clean = DOMPurify.sanitize(html, {
    ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'p'],
    ALLOWED_ATTR: []
  })
  return <div dangerouslySetInnerHTML={{ __html: clean }} />
}
```

#### セキュリティヘッダー
```typescript
// next.config.js
const securityHeaders = [
  {
    key: 'Content-Security-Policy',
    value: "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:;"
  },
  { key: 'X-Frame-Options', value: 'DENY' },
  { key: 'X-Content-Type-Options', value: 'nosniff' },
]
```

#### チェック項目
- [ ] ユーザー提供のHTMLがサニタイズされている
- [ ] CSPヘッダーが設定されている
- [ ] バリデーションなしの動的コンテンツ描画がない

### 6. CSRF保護

#### SameSiteクッキー
```python
response.set_cookie(
    key="session",
    value=session_id,
    httponly=True,
    secure=True,
    samesite="strict",
)
```

#### CSRFトークン
```python
from fastapi import Header, HTTPException

async def verify_csrf_token(x_csrf_token: str = Header(...)):
    if not csrf_service.verify(x_csrf_token):
        raise HTTPException(status_code=403, detail="無効なCSRFトークン")
```

#### チェック項目
- [ ] 状態変更操作にCSRFトークンが必要
- [ ] すべてのクッキーにSameSite=Strict
- [ ] ダブルサブミットクッキーパターンの実装

### 7. レート制限

#### FastAPIでのレート制限
```python
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)

@router.get("/api/search")
@limiter.limit("10/minute")
async def search(request: Request, q: str):
    ...
```

#### チェック項目
- [ ] すべてのAPIエンドポイントにレート制限がある
- [ ] 高コスト操作により厳しい制限がある
- [ ] IPベースのレート制限
- [ ] 認証ユーザーベースのレート制限

### 8. 機密データの漏洩防止

#### ログ
```python
# NEVER: 機密データをログに出力
logger.info("User login", email=email, password=password)
logger.info("Payment", card_number=card_number)

# ALWAYS: 機密データをマスク
logger.info("User login", email=email, user_id=user_id)
logger.info("Payment", last4=card.last4, user_id=user_id)
```

#### エラーメッセージ
```python
# NEVER: 内部情報を公開
@app.exception_handler(Exception)
async def error_handler(request: Request, exc: Exception):
    return JSONResponse(
        status_code=500,
        content={"error": str(exc), "traceback": traceback.format_exc()},  # 危険
    )

# ALWAYS: 一般的なエラーメッセージ
@app.exception_handler(Exception)
async def error_handler(request: Request, exc: Exception):
    logger.error("Internal error", error=str(exc), path=request.url.path)
    return JSONResponse(
        status_code=500,
        content={"error": "内部エラーが発生しました"},
    )
```

#### チェック項目
- [ ] ログにパスワード、トークン、シークレットがない
- [ ] ユーザー向けエラーメッセージが一般的
- [ ] 詳細エラーはサーバーログのみ
- [ ] スタックトレースがユーザーに公開されていない

### 9. メッセージブローカーのセキュリティ

#### メッセージのバリデーション
```python
from pydantic import BaseModel, ValidationError

class OrderEvent(BaseModel):
    tenant_id: UUID
    order_id: UUID
    timestamp: datetime
    items: list[OrderItem]

def handle_message(raw_message: bytes) -> None:
    try:
        message = OrderEvent.model_validate_json(raw_message)
    except ValidationError as e:
        logger.warning("Invalid message", error=str(e))
        return  # 不正メッセージは破棄
    process(message)
```

#### チェック項目
- [ ] メッセージキューからの消費前にPydanticでバリデーション済み
- [ ] トピック/チャネルにACLが設定されている
- [ ] 不正メッセージが安全に破棄される
- [ ] マルチテナントの場合: メッセージにテナント分離が保証されている

### 10. 依存パッケージのセキュリティ

```bash
# Python: 脆弱性チェック
pip-audit

# Node.js: 脆弱性チェック
npm audit

# 自動修正
npm audit fix

# ロックファイルを必ずコミット
git add uv.lock package-lock.json
```

#### チェック項目
- [ ] 依存パッケージが最新
- [ ] 既知の脆弱性がない
- [ ] ロックファイルがコミットされている
- [ ] 定期的なセキュリティアップデート

## デプロイ前セキュリティチェックリスト

本番デプロイ前に必ず確認:

- [ ] **シークレット**: ハードコードなし、すべて環境変数経由
- [ ] **入力バリデーション**: すべてのユーザー入力がバリデーション済み
- [ ] **SQLインジェクション**: すべてのクエリがパラメータ化
- [ ] **XSS**: ユーザーコンテンツがサニタイズ済み
- [ ] **CSRF**: 保護が有効
- [ ] **認証**: 適切なトークン管理
- [ ] **認可**: ロールチェック実装済み
- [ ] **レート制限**: 全エンドポイントで有効
- [ ] **HTTPS**: 本番で強制
- [ ] **セキュリティヘッダー**: CSP、X-Frame-Options設定済み
- [ ] **エラー処理**: エラーに機密データなし
- [ ] **ログ**: ログに機密データなし
- [ ] **依存パッケージ**: 最新、脆弱性なし
- [ ] **CORS**: 適切に設定
- [ ] **ファイルアップロード**: バリデーション済み（サイズ、形式）
- [ ] **マルチテナント（該当する場合）**: テナントデータ分離が保証されている
- [ ] **メッセージブローカー**: メッセージバリデーション済み

## 参考資料

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [FastAPI Security](https://fastapi.tiangolo.com/tutorial/security/)
- [Next.js Security](https://nextjs.org/docs/security)
