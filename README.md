# NutriMind — AI-Powered Nutrition & Fitness Tracker

<div align="center">

![NutriMind Logo](https://img.shields.io/badge/NutriMind-22c55e?style=for-the-badge&logo=leaf&logoColor=black)
![Next.js](https://img.shields.io/badge/Next.js-16-black?style=for-the-badge&logo=next.js)
![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi)
![TypeScript](https://img.shields.io/badge/TypeScript-3178C6?style=for-the-badge&logo=typescript)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?style=for-the-badge&logo=postgresql)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker)

**Your intelligent nutrition companion — track meals, analyze macros, and get personalized AI-powered guidance.**

[Live Demo](#-quick-start) · [Features](#-features) · [Tech Stack](#-tech-stack) · [API Docs](#-api-reference)

</div>

---

## ✨ Features

### 🍎 Meal & Nutrition Tracking
- Log breakfast, lunch, dinner, and snacks with detailed macro tracking
- Interactive CalorieRing visualization showing daily progress
- Animated MacroBars for protein, carbs, and fat targets
- Water intake tracker with 8-glass interface

### 🤖 AI Nutrition Coach
- Streaming AI chat powered by Anthropic Claude
- Personalized recommendations based on your daily intake
- Context-aware responses considering your nutrition goals
- Chat history persistence

### 📊 Smart Dashboard
- Real-time daily summary with date navigation
- 7-day weight progress chart (Recharts)
- Auto-calculated BMR, TDEE, and macro targets
- Goal-based nutrition targets

### 👤 User Profile
- Full measurements tracking (height, weight, activity level)
- Multiple dietary preferences and allergy management
- BMI calculation with health categorization
- Goal-based target recalculation

### 🛡️ Admin Panel
- User management with suspend/activate controls
- Platform analytics with growth charts
- Goal and activity level distribution insights

---

## 🏗️ Tech Stack

### Frontend
| Technology | Purpose |
|------------|---------|
| **Next.js 16** | React framework with Turbopack |
| **TypeScript** | Type-safe development |
| **Tailwind CSS v4** | Utility-first styling |
| **Framer Motion** | Animations & transitions |
| **Recharts** | Data visualization |
| **Radix UI** | Accessible component primitives |
| **Lucide React** | Icon library |

### Backend
| Technology | Purpose |
|------------|---------|
| **FastAPI** | Async Python web framework |
| **SQLAlchemy 2.0** | Async ORM with type safety |
| **PostgreSQL** | Primary database |
| **Redis** | Caching & session storage |
| **JWT + bcrypt** | Authentication |
| **Anthropic Claude** | AI chat integration |
| **Alembic** | Database migrations |

### Infrastructure
| Technology | Purpose |
|------------|---------|
| **Docker Compose** | Container orchestration |
| **python-jose** | JWT token handling |
| **pydantic v2** | Data validation |

---

## 🚀 Quick Start

### Prerequisites

- Docker & Docker Compose
- Node.js 18+ (for local frontend development)
- Python 3.12+ (for local backend development)
- Anthropic API key (for AI features)

### 1. Clone & Configure

```bash
git clone https://github.com/yourusername/nutrimind.git
cd nutrimind
```

Create `backend/.env`:

```env
DATABASE_URL=postgresql+asyncpg://postgres:postgres@localhost:5432/nutrimind
REDIS_URL=redis://localhost:6379
JWT_SECRET=your-super-secret-key-change-in-production
GEMINI_API_KEY=your-gemini-api-key
```

### 2. Start with Docker

```bash
docker-compose up -d
```

Services will be available at:
- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:8000
- **API Docs**: http://localhost:8000/docs

### 3. Seed Demo Data

```bash
docker-compose run backend python seed.py
```

**Demo credentials:**
- User: `demo@nutrimind.app` / `Demo123!`
- Admin: `admin@nutrimind.app` / `Admin123!`

### 4. Local Development

```bash
# Frontend
cd nutrimind && npm install && npm run dev

# Backend (separate terminal)
cd backend && pip install -r requirements.txt && uvicorn app.main:app --reload
```

---

## 📁 Project Structure

```
nutrimind/
├── public/                  # Static assets
├── src/
│   ├── app/                 # Next.js App Router
│   │   ├── (auth)/         # Auth pages (login, register)
│   │   ├── (dashboard)/    # Protected dashboard pages
│   │   │   ├── tracker/    # Daily nutrition tracking
│   │   │   ├── assistant/   # AI chat interface
│   │   │   └── profile/    # User settings
│   │   ├── (admin)/        # Admin panel pages
│   │   │   ├── users/      # User management
│   │   │   └── analytics/  # Platform analytics
│   │   └── page.tsx        # Landing page
│   ├── components/
│   │   ├── dashboard/      # Dashboard UI components
│   │   │   ├── CalorieRing.tsx
│   │   │   ├── MacroBar.tsx
│   │   │   ├── MealCard.tsx
│   │   │   ├── AddFoodModal.tsx
│   │   │   └── WaterTracker.tsx
│   │   ├── landing/        # Landing page sections
│   │   └── ui/             # Shared UI components
│   └── lib/
│       └── utils.ts        # Utility functions
└── package.json

backend/
├── app/
│   ├── api/v1/routes/      # API endpoints
│   │   ├── auth.py         # Authentication
│   │   ├── users.py        # User management
│   │   ├── tracker.py      # Food & water logging
│   │   └── ai.py           # AI chat
│   ├── models/             # SQLAlchemy models
│   ├── schemas/            # Pydantic schemas
│   ├── services/           # Business logic
│   └── core/               # Config, security, database
├── alembic/                # Database migrations
├── seed.py                 # Demo data seeder
└── requirements.txt
```

---

## 🔌 API Reference

### Authentication

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/v1/auth/register` | Create new account |
| `POST` | `/api/v1/auth/login` | Login (email or phone) |
| `POST` | `/api/v1/auth/refresh` | Refresh access token |

### User

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/v1/users/me` | Get current user profile |
| `PUT` | `/api/v1/users/me` | Update profile & recalculate targets |

### Tracker

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/v1/tracker/daily` | Get daily food/water summary |
| `POST` | `/api/v1/tracker/food` | Log a food entry |
| `PUT` | `/api/v1/tracker/food/{id}` | Update food entry |
| `DELETE` | `/api/v1/tracker/food/{id}` | Delete food entry |
| `POST` | `/api/v1/tracker/water` | Log water intake |
| `POST` | `/api/v1/tracker/weight` | Log weight entry |
| `GET` | `/api/v1/tracker/weight/history` | Get weight history |

### AI Assistant

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/v1/ai/chat` | Stream AI response (SSE) |
| `GET` | `/api/v1/ai/history` | Get chat history |
| `DELETE` | `/api/v1/ai/history` | Clear chat history |

### Admin

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/v1/users/admin/users` | List all users |
| `PUT` | `/api/v1/users/admin/users/{id}` | Update user status |
| `DELETE` | `/api/v1/users/admin/users/{id}` | Delete user |

---

## 🎨 Design System

### Color Palette

| Name | Hex | Usage |
|------|-----|-------|
| **Primary** | `#22c55e` | CTAs, success states, accents |
| **Background** | `#0a0a0a` | Page background |
| **Surface** | `#111111` | Cards, panels |
| **Border** | `#1a1a1a` | Dividers, borders |
| **Text Primary** | `#ffffff` | Headings, important text |
| **Text Secondary** | `#9ca3af` | Body text |
| **Text Muted** | `#6b7280` | Labels, hints |

### Typography

- **Font**: Inter (Google Fonts)
- **Headings**: Bold, 2xl–4xl
- **Body**: Regular, sm–base
- **Labels**: Medium, xs–sm

---

## 🔒 Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `DATABASE_URL` | PostgreSQL connection string | ✅ |
| `REDIS_URL` | Redis connection string | ✅ |
| `JWT_SECRET` | Secret for JWT signing | ✅ |
| `GEMINI_API_KEY` | Gemini API key (meal-photo + chat) | ✅ |

---

## 📈 Future Roadmap

- [ ] Image-based food recognition (AI vision)
- [ ] Social features (friends, challenges)
- [ ] Recipe suggestions based on preferences
- [ ] Apple Health / Google Fit integration
- [ ] Meal planning with weekly targets
- [ ] Custom food database upload

---

## 📄 License

MIT License — feel free to use this for your own projects.

---

<div align="center">

**Built with ❤️ for better nutrition**

</div>