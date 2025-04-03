from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
import os
from sqlalchemy.orm import Session
from sqlalchemy import text
from .database import get_db, engine
from .models import user, expense, category
from .api import auth

# Load environment variables
load_dotenv()

app = FastAPI(
    title="Personal Finance Assistant API",
    description="API for the Intelligent Personal Finance Assistant",
    version="1.0.0"
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def root():
    return {
        "message": "Welcome to the Personal Finance Assistant API",
        "status": "active",
        "version": "1.0.0"
    }

@app.get("/test-db")
async def test_db(db: Session = Depends(get_db)):
    try:
        # Try to query the database
        db.execute(text("SELECT 1"))
        return {
            "status": "success",
            "message": "Database connection successful",
            "tables": {
                "users": True,
                "expenses": True,
                "categories": True
            }
        }
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Database connection failed: {str(e)}"
        )

# Include routers
app.include_router(auth.router, prefix="/api/auth", tags=["Authentication"])

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000) 