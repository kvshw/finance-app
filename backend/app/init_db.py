from app.database import engine
from app.models.user import User
from app.models.expense import Expense
from app.models.category import Category

def init_db():
    # Import all models here
    from app.models.user import User
    from app.models.expense import Expense
    from app.models.category import Category
    
    # Create all tables
    User.metadata.create_all(bind=engine)
    Category.metadata.create_all(bind=engine)
    Expense.metadata.create_all(bind=engine)

if __name__ == "__main__":
    print("Creating database tables...")
    init_db()
    print("Database tables created successfully!") 