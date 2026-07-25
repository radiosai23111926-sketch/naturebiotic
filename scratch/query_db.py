import sqlite3
import os

db_path = os.path.expanduser(r'~\Documents\nature_biotic_local.db')
print("DB Path:", db_path)

if not os.path.exists(db_path):
    print("Database file does not exist at path.")
else:
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # List tables
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
    tables = cursor.fetchall()
    print("Tables in DB:", tables)
    
    # Query store_transactions
    try:
        cursor.execute("SELECT * FROM store_transactions ORDER BY created_at DESC LIMIT 20;")
        columns = [d[0] for d in cursor.description]
        rows = cursor.fetchall()
        print("\nStore Transactions (Last 20):")
        print("-" * 100)
        print(" | ".join(columns))
        print("-" * 100)
        for r in rows:
            print(" | ".join(str(val) for val in r))
    except sqlite3.OperationalError as e:
        print("Error reading store_transactions:", e)
        
    conn.close()
