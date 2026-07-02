---
paths:
  - "**/backend/**/*.py"
---

# Clean Architecture Pattern

Python services follow Clean Architecture with strict dependency inversion:

```
┌─────────────────────────────────────────────────┐
│ presentation/  (FastAPI Layer)                 │
│ - route/          API endpoints                │
│ - model/          Request/Response Pydantic    │
│ - dependency.py   Dependency injection         │
├─────────────────────────────────────────────────┤
│ app/  (Application/Use Case Layer)             │
│ - usecase/        Orchestration only (※)      │
│ - model/          View models (ends with View) │
├─────────────────────────────────────────────────┤
│ domain/  (Domain Layer)                        │
│ - model/          Core business entities       │
│ - repository/     Abstract interfaces (ABC)    │
├─────────────────────────────────────────────────┤
│ adapter/  (Infrastructure Layer)               │
│ - model/          SQLModel database models     │
│ - repository/     Repository implementations   │
└─────────────────────────────────────────────────┘
```

## Critical Dependency Rules

- **Dependency Direction**: Adapter → Domain ← App ← Presentation (always inward)
- **Domain Layer**: NEVER depends on external frameworks or adapters
- **App Layer**: NEVER accesses database directly (must use domain repository interfaces)
- **Repository Pattern**: Domain defines abstract interfaces, Adapter provides implementations

## Application層（usecase/）の責務制限

Application層はオーケストレーション専用。以下のみ許可:
1. リポジトリ/外部サービスの呼び出し
2. Domain層のメソッド/サービスへの委譲
3. トランザクション制御
4. 例外の変換・再送出

### Application層に書いてはいけないもの（Domain層へ移動すること）

| 禁止パターン | 例 | 移動先 |
|-------------|-----|--------|
| **ビジネス条件分岐** | `if count >= max_limit:` / `if license_type == TEMPORARY:` | Domain Entity メソッド or Policy クラス |
| **値の計算・変換** | 統計計算、占有率、トレンド判定、チェックサム | Value Object or Domain Service |
| **ビジネスバリデーション** | 所属関係の検証、許可リストとの突合 | Domain Entity メソッド |
| **命名規則・採番** | `f"item-{num:03d}"` | Value Object（ファクトリメソッド） |
| **ストレージパス生成** | `f"uploads/{user_id}/{file_id}"` | Value Object |
| **バケット定義・閾値定数** | 分布区間、上限値、タイムアウト値 | Domain層の定数 or Value Object |
| **比較演算子の分岐** | `if operator == "greater_than":` | Domain Service（ConditionEvaluator等） |
| **データ形式のパース** | base64デコード、data URIパース | Value Object（ファクトリメソッド） |

### Domain層での受け皿パターン

```python
# ❌ BAD: UseCase内でビジネス判定
class OrderUseCase:
    async def create(self, ...):
        if current_count >= max_orders:  # ビジネスルール流出
            raise LimitExceededError()

# ✅ GOOD: Domain層のPolicyに委譲
# domain/service/order_policy.py
class OrderPolicy:
    @staticmethod
    def check_capacity(max_orders: int | None, current_count: int) -> None:
        if max_orders is None:
            return  # 無制限
        if current_count >= max_orders:
            raise OrderLimitExceededError(...)

# usecase/order.py
class OrderUseCase:
    async def create(self, ...):
        capacity = await self.order_repository.get_capacity(...)
        OrderPolicy.check_capacity(*capacity)  # 委譲のみ
```

```python
# ❌ BAD: UseCase内で値を計算
class SalesReportUseCase:
    def _calc(self, current, previous):
        if previous < current:
            return ReportTrend.INCREASING  # ビジネスルール流出

# ✅ GOOD: Value Objectに計算ロジックを内包
# domain/model/sales_report.py
class SalesReport:
    @staticmethod
    def from_values(current: int, previous: int) -> ReportTrend:
        if previous < current:
            return ReportTrend.INCREASING
        ...
```

## DTO Conversion Pattern

Each layer has specific conversion responsibilities:
- **Presentation → App**: `to_{entity}_filter_view()`
- **App → Domain**: `to_{entity}_filter()`
- **Adapter → Domain**: `to_{entity}()`
- **Domain → App**: `from_{entity}()` (class method in App models)
- **App → Presentation**: `from_{entity}_view()` (class method in Presentation models)
