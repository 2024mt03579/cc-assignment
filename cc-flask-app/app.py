from flask import Flask, render_template, request, redirect
from flask_sqlalchemy import SQLAlchemy
import os

app = Flask(__name__)
app.secret_key = os.getenv('SECRET_KEY', 'a-very-strong-secret-key')

# Database configuration (for RDS, using PyMySQL)
DB_HOST = os.getenv('DB_ENDPOINT', 'localhost')
DB_USER = os.getenv('DB_USER', 'admin')
DB_PASSWORD = os.getenv('DB_PASSWORD', 'my-secret-password')
DB_NAME = os.getenv('DB_NAME', 'cc_db')
DB_PORT = int(os.getenv('DB_PORT', '3306'))

app.config['SQLALCHEMY_DATABASE_URI'] = f'mysql+pymysql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)

# Define the Contact model
class Contact(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(255), nullable=False)
    email = db.Column(db.String(255), nullable=False)
    message = db.Column(db.Text, nullable=False)

# Route for home page
@app.route('/')
def index():
    return render_template('index.html')

# Route for form submission
@app.route('/contact', methods=['POST'])
def contact():
    name = request.form.get('name')
    email = request.form.get('email')
    message = request.form.get('message')

    new_contact = Contact(name=name, email=email, message=message)
    db.session.add(new_contact)
    db.session.commit()

    return redirect('/')

@app.route('/messages')
def messages():
    all_contacts = Contact.query.all()
    return render_template('messages.html', contacts=all_contacts)

if __name__ == '__main__':
    with app.app_context():
        db.create_all()  # Creates the tables if they don't exist
    app.run(debug=True, port=8000)