"""add age height weight to users

Revision ID: a1b2c3d4e5f6
Revises: 1d883a5cac6f
Create Date: 2026-05-19

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a1b2c3d4e5f6'
down_revision: Union[str, Sequence[str], None] = '1d883a5cac6f'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Add age, height, weight columns to users table."""
    op.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS age VARCHAR;")
    op.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS height VARCHAR;")
    op.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS weight VARCHAR;")


def downgrade() -> None:
    """Remove age, height, weight columns from users table."""
    op.drop_column('users', 'weight')
    op.drop_column('users', 'height')
    op.drop_column('users', 'age')
