from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Enum, Boolean
from sqlalchemy.orm import relationship
from datetime import datetime
import enum
from ..database import Base

class TransactionType(enum.Enum):
    EXPENSE = "expense"
    INCOME = "income"

class Expense(Base):
    __tablename__ = "expenses"

    id = Column(Integer, primary_key=True, index=True)
    amount = Column(Float, nullable=False)
    description = Column(String, nullable=False)
    transaction_type = Column(Enum(TransactionType), nullable=False, default=TransactionType.EXPENSE)
    date = Column(DateTime, default=datetime.utcnow)
    category_id = Column(Integer, ForeignKey("categories.id"))
    user_id = Column(Integer, ForeignKey("users.id"))
    notes = Column(String)
    is_recurring = Column(Boolean, default=False)
    recurring_frequency = Column(String, nullable=True)  # daily, weekly, monthly, yearly
    tags = Column(String)  # Comma-separated tags
    
    # Relationships
    user = relationship("User", back_populates="expenses")
    category = relationship("Category", back_populates="expenses")
    
    def __repr__(self):
        return f"<Expense {self.description} - {self.amount}>" 