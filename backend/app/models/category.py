from sqlalchemy import Column, Integer, String, ForeignKey
from sqlalchemy.orm import relationship
from ..database import Base

class Category(Base):
    __tablename__ = "categories"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False, unique=True)
    description = Column(String)
    icon = Column(String)  # For storing icon name/identifier
    color = Column(String)  # For storing color code
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)  # Null for system categories
    
    # Relationships
    user = relationship("User", back_populates="categories")
    expenses = relationship("Expense", back_populates="category")
    
    def __repr__(self):
        return f"<Category {self.name}>" 