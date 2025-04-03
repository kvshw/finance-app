from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import create_engine, Column, Integer, String, Boolean, Float, DateTime, ForeignKey, text, inspect
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session, relationship, backref
from passlib.context import CryptContext
from datetime import datetime, timedelta
from jose import JWTError, jwt
from typing import Optional, List
import os
from dotenv import load_dotenv
from pydantic import BaseModel

# Load environment variables
load_dotenv()

# Database setup
SQLALCHEMY_DATABASE_URL = "sqlite:///./finance_app.db"
engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# Security
SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key-here")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

pwd_context = CryptContext(schemes=["argon2"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="api/auth/login")

# Models
class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True)
    hashed_password = Column(String)
    is_active = Column(Boolean, default=True)
    
    transactions = relationship("Transaction", back_populates="user")
    categories = relationship("Category", back_populates="user")

class Category(Base):
    __tablename__ = "categories"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    type = Column(String, nullable=False)  # 'income' or 'expense'
    user_id = Column(Integer, ForeignKey("users.id"))
    transaction_count = Column(Integer, default=0)
    parent_id = Column(Integer, ForeignKey("categories.id"), nullable=True)
    is_predefined = Column(Boolean, default=False)
    budget = Column(Float, nullable=True)

    user = relationship("User", back_populates="categories")
    subcategories = relationship("Category", backref=backref("parent", remote_side=[id]))

class Transaction(Base):
    __tablename__ = "transactions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    title = Column(String)
    amount = Column(Float)
    category = Column(String)
    date = Column(DateTime)
    created_at = Column(DateTime, default=datetime.utcnow)
    is_recurring = Column(Boolean, default=False)
    recurrence_frequency = Column(String(50))
    next_recurrence_date = Column(DateTime)
    type = Column(String(10))

    user = relationship("User", back_populates="transactions")

class TransactionCreate(BaseModel):
    title: str
    amount: float
    type: str
    category: str
    date: datetime
    is_recurring: bool = False
    recurrence_frequency: Optional[str] = None
    next_recurrence_date: Optional[datetime] = None

# Create tables
Base.metadata.create_all(bind=engine)

# FastAPI app
app = FastAPI()

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
)

# Dependency
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Helper functions
def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

async def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        if email is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    
    user = db.query(User).filter(User.email == email).first()
    if user is None:
        raise credentials_exception
    return user

# Routes
@app.post("/api/auth/register")
async def register(user_data: dict, db: Session = Depends(get_db)):
    print(f"Received registration request for email: {user_data.get('email')}")
    
    # Check if user already exists
    db_user = db.query(User).filter(User.email == user_data['email']).first()
    if db_user:
        print("User already exists")
        raise HTTPException(
            status_code=400,
            detail="Email already registered"
        )
    
    try:
        # Create new user
        hashed_password = get_password_hash(user_data['password'])
        db_user = User(email=user_data['email'], hashed_password=hashed_password)
        db.add(db_user)
        db.commit()
        db.refresh(db_user)
        print("User created successfully")
        
        # Create access token
        access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        access_token = create_access_token(
            data={"sub": db_user.email}, expires_delta=access_token_expires
        )
        
        return {
            "message": "User created successfully",
            "access_token": access_token,
            "token_type": "bearer"
        }
    except Exception as e:
        print(f"Error during registration: {str(e)}")
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"Error creating user: {str(e)}"
        )

@app.post("/api/auth/login")
async def login(user_data: dict, db: Session = Depends(get_db)):
    print("=== Login Request ===")
    print(f"Received data: {user_data}")
    
    try:
        email = user_data.get('email')
        password = user_data.get('password')
        
        if not email or not password:
            print("Missing email or password")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email and password are required"
            )
        
        print(f"Looking for user with email: {email}")
        user = db.query(User).filter(User.email == email).first()
        
        if not user:
            print("User not found")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Incorrect email or password",
                headers={"WWW-Authenticate": "Bearer"},
            )
        
        print("User found, verifying password")
        if not verify_password(password, user.hashed_password):
            print("Invalid password")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Incorrect email or password",
                headers={"WWW-Authenticate": "Bearer"},
            )
        
        print("Password verified, generating token")
        access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        access_token = create_access_token(
            data={"sub": user.email}, expires_delta=access_token_expires
        )
        print("Token generated successfully")
        return {"access_token": access_token, "token_type": "bearer"}
    except HTTPException as he:
        print(f"HTTP Exception: {he.detail}")
        raise he
    except Exception as e:
        print(f"Unexpected error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {str(e)}"
        )

@app.post("/api/transactions/expense")
async def create_expense(
    transaction_data: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    print(f"Received expense data: {transaction_data}")
    try:
        # Log the parsed values
        amount = abs(float(transaction_data['amount'])) * -1
        date = datetime.fromisoformat(transaction_data['date'].replace('Z', '+00:00'))
        print(f"Parsed amount: {amount}")
        print(f"Parsed date: {date}")
        
        transaction = Transaction(
            user_id=current_user.id,
            title=transaction_data['title'],
            amount=amount,
            category=transaction_data['category'],
            date=date,
        )
        print(f"Created transaction object: {transaction.title}, {transaction.amount}, {transaction.category}, {transaction.date}")
        db.add(transaction)
        db.commit()
        db.refresh(transaction)
        print(f"Successfully added expense with ID: {transaction.id}")
        return {"message": "Expense added successfully", "id": transaction.id, "status": "success"}
    except Exception as e:
        print(f"Error in create_expense: {str(e)}")
        print(f"Error type: {type(e)}")
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"Error adding expense: {str(e)}"
        )

@app.post("/api/transactions/income")
async def create_income(
    transaction_data: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    print(f"Received income data: {transaction_data}")
    try:
        # Log the parsed values
        amount = abs(float(transaction_data['amount']))
        date = datetime.fromisoformat(transaction_data['date'].replace('Z', '+00:00'))
        print(f"Parsed amount: {amount}")
        print(f"Parsed date: {date}")
        
        transaction = Transaction(
            user_id=current_user.id,
            title=transaction_data['title'],
            amount=amount,
            category=transaction_data['category'],
            date=date,
        )
        print(f"Created transaction object: {transaction.title}, {transaction.amount}, {transaction.category}, {transaction.date}")
        db.add(transaction)
        db.commit()
        db.refresh(transaction)
        print(f"Successfully added income with ID: {transaction.id}")
        return {"message": "Income added successfully", "id": transaction.id, "status": "success"}
    except Exception as e:
        print(f"Error in create_income: {str(e)}")
        print(f"Error type: {type(e)}")
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"Error adding income: {str(e)}"
        )

@app.get("/api/transactions")
async def get_transactions(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    transactions = db.query(Transaction).filter(
        Transaction.user_id == current_user.id
    ).order_by(Transaction.date.desc()).all()
    
    return [{
        "id": t.id,
        "title": t.title,
        "amount": t.amount,
        "category": t.category,
        "date": t.date.isoformat(),
    } for t in transactions]

# Category routes
@app.get("/api/categories")
async def get_categories(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Get user's custom categories
    categories = db.query(Category).filter(
        Category.user_id == current_user.id,
        Category.parent_id == None  # Only get top-level categories
    ).all()
    
    # Get predefined categories
    predefined_categories = db.query(Category).filter(
        Category.is_predefined == True,
        Category.parent_id == None
    ).all()
    
    all_categories = predefined_categories + categories
    
    return [{
        "id": c.id,
        "name": c.name,
        "type": c.type,
        "transaction_count": c.transaction_count,
        "parent_id": c.parent_id,
        "is_predefined": c.is_predefined,
        "subcategories": [{
            "id": sub.id,
            "name": sub.name,
            "type": sub.type,
            "transaction_count": sub.transaction_count,
        } for sub in c.subcategories]
    } for c in all_categories]

@app.post("/api/categories")
async def create_category(
    category_data: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    try:
        category = Category(
            name=category_data['name'],
            type=category_data['type'],
            user_id=current_user.id,
            parent_id=category_data.get('parent_id'),
        )
        db.add(category)
        db.commit()
        db.refresh(category)
        return {
            "id": category.id,
            "name": category.name,
            "type": category.type,
            "transaction_count": category.transaction_count,
            "parent_id": category.parent_id,
            "subcategories": []
        }
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"Error creating category: {str(e)}"
        )

@app.delete("/api/categories/{category_id}")
async def delete_category(
    category_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    category = db.query(Category).filter(
        Category.id == category_id,
        Category.user_id == current_user.id
    ).first()
    
    if not category:
        raise HTTPException(
            status_code=404,
            detail="Category not found"
        )
    
    try:
        db.delete(category)
        db.commit()
        return {"message": "Category deleted successfully"}
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"Error deleting category: {str(e)}"
        )

@app.put("/api/categories/{category_id}")
async def update_category(
    category_id: int,
    category_data: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    category = db.query(Category).filter(
        Category.id == category_id,
        Category.user_id == current_user.id
    ).first()
    
    if not category:
        raise HTTPException(
            status_code=404,
            detail="Category not found"
        )
    
    try:
        category.name = category_data['name']
        category.type = category_data['type']
        db.commit()
        db.refresh(category)
        return {
            "id": category.id,
            "name": category.name,
            "type": category.type,
            "transaction_count": category.transaction_count,
        }
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"Error updating category: {str(e)}"
        )

@app.get("/")
async def root():
    return {"message": "Welcome to the Finance Assistant API"}

# Add predefined categories on startup
def create_predefined_categories(db: Session):
    predefined_categories = [
        {"name": "Salary", "type": "income", "subcategories": ["Full-time", "Part-time", "Freelance"]},
        {"name": "Business", "type": "income", "subcategories": ["Sales", "Services", "Investments"]},
        {"name": "Food", "type": "expense", "subcategories": ["Groceries", "Restaurants", "Takeout"]},
        {"name": "Transportation", "type": "expense", "subcategories": ["Public Transport", "Car", "Taxi"]},
        {"name": "Housing", "type": "expense", "subcategories": ["Rent", "Mortgage", "Utilities"]},
        {"name": "Entertainment", "type": "expense", "subcategories": ["Movies", "Games", "Events"]},
    ]
    
    for category_data in predefined_categories:
        # Check if category exists
        existing = db.query(Category).filter(
            Category.name == category_data["name"],
            Category.is_predefined == True
        ).first()
        
        if not existing:
            category = Category(
                name=category_data["name"],
                type=category_data["type"],
                is_predefined=True
            )
            db.add(category)
            db.commit()
            db.refresh(category)
            
            # Add subcategories
            for subcategory_name in category_data["subcategories"]:
                subcategory = Category(
                    name=subcategory_name,
                    type=category_data["type"],
                    parent_id=category.id,
                    is_predefined=True
                )
                db.add(subcategory)
            
            db.commit()

def update_database_schema():
    inspector = inspect(engine)
    existing_columns = [col['name'] for col in inspector.get_columns('categories')]
    
    if 'parent_id' not in existing_columns:
        with engine.connect() as conn:
            conn.execute(text("ALTER TABLE categories ADD COLUMN parent_id INTEGER"))
            conn.execute(text("ALTER TABLE categories ADD COLUMN is_predefined BOOLEAN DEFAULT FALSE"))
            conn.execute(text("ALTER TABLE categories ADD COLUMN budget DECIMAL(10, 2)"))
            conn.commit()
    
    # Add recurring transaction support and type column
    existing_columns = [col['name'] for col in inspector.get_columns('transactions')]
    if 'is_recurring' not in existing_columns:
        with engine.connect() as conn:
            conn.execute(text("ALTER TABLE transactions ADD COLUMN is_recurring BOOLEAN DEFAULT FALSE"))
            conn.execute(text("ALTER TABLE transactions ADD COLUMN recurrence_frequency VARCHAR(50)"))
            conn.execute(text("ALTER TABLE transactions ADD COLUMN next_recurrence_date DATE"))
            conn.execute(text("ALTER TABLE transactions ADD COLUMN type VARCHAR(10)"))
            conn.commit()

# Update the database schema before creating predefined categories
update_database_schema()
create_predefined_categories(SessionLocal())

@app.get("/api/categories/stats")
async def get_category_stats(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Get all categories for the user
    categories = db.query(Category).filter(
        Category.user_id == current_user.id,
        Category.parent_id == None  # Only get top-level categories
    ).all()
    
    # Get predefined categories
    predefined_categories = db.query(Category).filter(
        Category.is_predefined == True,
        Category.parent_id == None
    ).all()
    
    all_categories = predefined_categories + categories
    
    stats = []
    for category in all_categories:
        # Get transactions for this category
        transactions = db.query(Transaction).filter(
            Transaction.user_id == current_user.id,
            Transaction.category == category.name
        ).all()
        
        # Calculate total amount and transaction count
        total_amount = sum(t.amount for t in transactions)
        transaction_count = len(transactions)
        
        # Get recent transactions (last 5)
        recent_transactions = sorted(
            transactions,
            key=lambda t: t.date,
            reverse=True
        )[:5]
        
        stats.append({
            "name": category.name,
            "type": category.type,
            "total_amount": total_amount,
            "transaction_count": transaction_count,
            "budget": category.budget,
            "recent_transactions": [
                {
                    "id": t.id,
                    "amount": t.amount,
                    "description": t.title,
                    "date": t.date.isoformat(),
                }
                for t in recent_transactions
            ],
        })
    
    return stats

@app.post("/api/categories/{category_name}/budget")
async def set_category_budget(
    category_name: str,
    budget_data: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Find the category
    category = db.query(Category).filter(
        Category.name == category_name,
        Category.user_id == current_user.id
    ).first()
    
    if not category:
        raise HTTPException(
            status_code=404,
            detail="Category not found"
        )
    
    try:
        # Update the budget
        category.budget = budget_data['budget']
        db.commit()
        return {"message": "Budget updated successfully"}
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"Error updating budget: {str(e)}"
        )

@app.post("/api/transactions")
async def create_transaction(
    transaction_data: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    try:
        print(f"Received transaction data: {transaction_data}")  # Debug log
        
        # Validate required fields
        required_fields = ['title', 'amount', 'type', 'category', 'date']
        for field in required_fields:
            if field not in transaction_data:
                raise HTTPException(
                    status_code=400,
                    detail=f"Missing required field: {field}"
                )
        
        # Parse amount
        try:
            amount = float(transaction_data['amount'])
        except (ValueError, TypeError):
            raise HTTPException(
                status_code=400,
                detail="Invalid amount format"
            )
        
        # Parse date
        try:
            date_str = transaction_data['date']
            if 'T' in date_str:
                date = datetime.fromisoformat(date_str.replace('Z', '+00:00'))
            else:
                date = datetime.strptime(date_str, "%Y-%m-%d %H:%M:%S")
        except (ValueError, TypeError) as e:
            print(f"Date parsing error: {str(e)}")  # Debug log
            raise HTTPException(
                status_code=400,
                detail=f"Invalid date format: {date_str}"
            )
        
        # Parse next_recurrence_date if it exists
        next_recurrence_date = None
        if transaction_data.get("next_recurrence_date"):
            try:
                next_date_str = transaction_data["next_recurrence_date"]
                if 'T' in next_date_str:
                    next_recurrence_date = datetime.fromisoformat(next_date_str.replace('Z', '+00:00'))
                else:
                    next_recurrence_date = datetime.strptime(next_date_str, "%Y-%m-%d %H:%M:%S")
            except (ValueError, TypeError) as e:
                print(f"Next recurrence date parsing error: {str(e)}")  # Debug log
                raise HTTPException(
                    status_code=400,
                    detail=f"Invalid next recurrence date format: {next_date_str}"
                )
        
        # Create the transaction
        transaction = Transaction(
            user_id=current_user.id,
            title=transaction_data["title"],
            amount=amount,
            type=transaction_data["type"],
            category=transaction_data["category"],
            date=date,
            is_recurring=transaction_data.get("is_recurring", False),
            recurrence_frequency=transaction_data.get("recurrence_frequency"),
            next_recurrence_date=next_recurrence_date
        )
        
        print(f"Creating transaction: {transaction.__dict__}")  # Debug log
        
        db.add(transaction)
        db.commit()
        db.refresh(transaction)
        
        return {
            "id": transaction.id,
            "title": transaction.title,
            "amount": transaction.amount,
            "type": transaction.type,
            "category": transaction.category,
            "date": transaction.date.isoformat(),
            "is_recurring": transaction.is_recurring,
            "recurrence_frequency": transaction.recurrence_frequency,
            "next_recurrence_date": transaction.next_recurrence_date.isoformat() if transaction.next_recurrence_date else None
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error creating transaction: {str(e)}")  # Debug log
        print(f"Error type: {type(e)}")  # Debug log
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"Error creating transaction: {str(e)}"
        )

@app.post("/api/transactions/process-recurring")
async def process_recurring_transactions(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    try:
        # Get all recurring transactions that are due
        today = datetime.now().date()
        recurring_transactions = db.query(Transaction).filter(
            Transaction.user_id == current_user.id,
            Transaction.is_recurring == True,
            Transaction.next_recurrence_date <= today
        ).all()
        
        processed_transactions = []
        
        for transaction in recurring_transactions:
            # Create a new transaction based on the recurring one
            new_transaction = Transaction(
                user_id=current_user.id,
                title=transaction.title,
                amount=transaction.amount,
                type=transaction.type,
                category=transaction.category,
                date=datetime.now(),
                is_recurring=True,
                recurrence_frequency=transaction.recurrence_frequency
            )
            
            # Calculate next recurrence date
            if transaction.recurrence_frequency == "daily":
                new_transaction.next_recurrence_date = today + timedelta(days=1)
            elif transaction.recurrence_frequency == "weekly":
                new_transaction.next_recurrence_date = today + timedelta(weeks=1)
            elif transaction.recurrence_frequency == "monthly":
                # Add one month, handling year rollover
                next_month = today.month + 1
                next_year = today.year
                if next_month > 12:
                    next_month = 1
                    next_year += 1
                new_transaction.next_recurrence_date = today.replace(
                    month=next_month,
                    year=next_year
                )
            elif transaction.recurrence_frequency == "yearly":
                new_transaction.next_recurrence_date = today.replace(
                    year=today.year + 1
                )
            elif transaction.recurrence_frequency == "custom":
                # For custom frequency, we'll keep the same interval as before
                interval = transaction.next_recurrence_date - transaction.date
                new_transaction.next_recurrence_date = today + interval
            
            # Update the original transaction's next recurrence date
            transaction.next_recurrence_date = new_transaction.next_recurrence_date
            
            db.add(new_transaction)
            processed_transactions.append({
                "id": new_transaction.id,
                "title": new_transaction.title,
                "amount": new_transaction.amount,
                "type": new_transaction.type,
                "category": new_transaction.category,
                "date": new_transaction.date.isoformat(),
                "next_recurrence_date": new_transaction.next_recurrence_date.isoformat()
            })
        
        db.commit()
        return {"processed_transactions": processed_transactions}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/transactions/search")
async def search_transactions(
    query: str = None,
    category: str = None,
    start_date: str = None,
    end_date: str = None,
    min_amount: float = None,
    max_amount: float = None,
    sort_by: str = "date",
    sort_order: str = "desc",
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    try:
        # Start with base query
        base_query = db.query(Transaction).filter(Transaction.user_id == current_user.id)
        
        # Apply filters
        if query:
            base_query = base_query.filter(Transaction.title.ilike(f"%{query}%"))
        if category:
            base_query = base_query.filter(Transaction.category == category)
        if start_date:
            base_query = base_query.filter(Transaction.date >= datetime.fromisoformat(start_date))
        if end_date:
            base_query = base_query.filter(Transaction.date <= datetime.fromisoformat(end_date))
        if min_amount is not None:
            base_query = base_query.filter(Transaction.amount >= min_amount)
        if max_amount is not None:
            base_query = base_query.filter(Transaction.amount <= max_amount)
        
        # Apply sorting
        if sort_by == "amount":
            base_query = base_query.order_by(Transaction.amount.desc() if sort_order == "desc" else Transaction.amount.asc())
        elif sort_by == "title":
            base_query = base_query.order_by(Transaction.title.desc() if sort_order == "desc" else Transaction.title.asc())
        else:  # Default to date
            base_query = base_query.order_by(Transaction.date.desc() if sort_order == "desc" else Transaction.date.asc())
        
        # Execute query
        transactions = base_query.all()
        
        return [
            {
                "id": t.id,
                "title": t.title,
                "amount": t.amount,
                "type": t.type,
                "category": t.category,
                "date": t.date.isoformat(),
                "is_recurring": t.is_recurring,
                "recurrence_frequency": t.recurrence_frequency,
                "next_recurrence_date": t.next_recurrence_date.isoformat() if t.next_recurrence_date else None
            }
            for t in transactions
        ]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/transactions/recurring")
async def get_recurring_transactions(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    try:
        recurring_transactions = db.query(Transaction).filter(
            Transaction.user_id == current_user.id,
            Transaction.is_recurring == True
        ).all()
        
        return [
            {
                "id": t.id,
                "title": t.title,
                "amount": t.amount,
                "type": t.type,
                "category": t.category,
                "date": t.date.isoformat(),
                "recurrence_frequency": t.recurrence_frequency,
                "next_recurrence_date": t.next_recurrence_date.isoformat() if t.next_recurrence_date else None
            }
            for t in recurring_transactions
        ]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/api/transactions/{transaction_id}")
async def update_transaction(
    transaction_id: int,
    transaction: TransactionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    try:
        db_transaction = db.query(Transaction).filter(
            Transaction.id == transaction_id,
            Transaction.user_id == current_user.id
        ).first()
        
        if not db_transaction:
            raise HTTPException(status_code=404, detail="Transaction not found")
        
        # Update transaction fields
        db_transaction.title = transaction.title
        db_transaction.amount = transaction.amount
        db_transaction.category = transaction.category
        db_transaction.date = transaction.date
        db_transaction.is_recurring = transaction.is_recurring
        db_transaction.recurrence_frequency = transaction.recurrence_frequency
        db_transaction.next_recurrence_date = transaction.next_recurrence_date
        
        db.commit()
        db.refresh(db_transaction)
        
        return {"message": "Transaction updated successfully"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/api/transactions/{transaction_id}")
async def delete_transaction(
    transaction_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    try:
        db_transaction = db.query(Transaction).filter(
            Transaction.id == transaction_id,
            Transaction.user_id == current_user.id
        ).first()
        
        if not db_transaction:
            raise HTTPException(status_code=404, detail="Transaction not found")
        
        db.delete(db_transaction)
        db.commit()
        
        return {"message": "Transaction deleted successfully"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e)) 