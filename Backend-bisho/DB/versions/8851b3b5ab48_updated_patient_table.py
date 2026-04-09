"""updated patient table

Revision ID: 8851b3b5ab48
Revises: 333316ff1fcf
Create Date: 2026-04-08 14:45:11.763396

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '8851b3b5ab48'
down_revision: Union[str, Sequence[str], None] = '333316ff1fcf'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
