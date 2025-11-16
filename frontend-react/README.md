# OpenProject React Frontend

Modern, mobile-first React frontend for OpenProject built with cutting-edge technologies.

## 🚀 Tech Stack

- **React 19** - Latest React with modern features
- **TypeScript 5.8** - Type-safe development
- **Vite 6** - Lightning-fast build tool
- **Tailwind CSS 3.4** - Utility-first CSS framework
- **React Router 7** - Modern routing solution
- **TanStack Query 5** - Powerful async state management
- **Radix UI** - Accessible component primitives
- **Lucide Icons** - Beautiful icon library
- **Vitest** - Fast unit testing
- **PWA Support** - Offline-first capabilities

## 📱 Mobile-First Design

This frontend is built with a mobile-first approach:

- Touch-optimized UI components (minimum 44px touch targets)
- Responsive design that works on all screen sizes
- Bottom navigation for mobile devices
- Sidebar navigation for desktop
- Safe area support for notched devices (iPhone X+)
- PWA capabilities for app-like experience

## 🏗️ Project Structure

```
frontend-react/
├── src/
│   ├── components/           # Reusable components
│   │   ├── ui/              # Base UI components (Button, Card, etc.)
│   │   └── layout/          # Layout components (Nav, Sidebar)
│   ├── features/            # Feature-based modules
│   │   ├── dashboard/       # Home dashboard
│   │   ├── workPackages/    # Work packages feature
│   │   ├── calendar/        # Calendar feature
│   │   └── reports/         # Reports feature
│   ├── lib/                 # Utilities and helpers
│   │   ├── api-client.ts    # API client for OpenProject API v3
│   │   └── utils.ts         # Utility functions
│   ├── hooks/               # Custom React hooks
│   ├── types/               # TypeScript type definitions
│   │   └── api.ts           # OpenProject API types
│   ├── styles/              # Global styles
│   │   └── globals.css      # Tailwind + custom CSS
│   ├── App.tsx              # Main app component
│   └── main.tsx             # Entry point
├── index.html               # HTML template
├── package.json             # Dependencies
├── tsconfig.json            # TypeScript config
├── vite.config.ts           # Vite config
├── tailwind.config.js       # Tailwind config
└── README.md                # This file
```

## 🛠️ Getting Started

### Prerequisites

- Node.js 22+ (matches OpenProject requirement)
- npm 10+

### Installation

```bash
cd frontend-react
npm install
```

### Development

Start the development server:

```bash
npm run dev
```

The app will be available at `http://localhost:3000`

### Building

Build for production:

```bash
npm run build
```

Preview production build:

```bash
npm run preview
```

### Testing

Run tests:

```bash
npm test
```

Run tests with UI:

```bash
npm run test:ui
```

### Linting & Formatting

```bash
# Lint code
npm run lint

# Format code
npm run format

# Type check
npm run type-check
```

## 🎨 Design System

The frontend uses a custom design system built on:

- **Tailwind CSS** for utility classes
- **Radix UI** for accessible primitives
- **CSS Variables** for theming
- **Dark mode** support (coming soon)

### Color Palette

- **Primary**: OpenProject Blue (#1A67A3)
- **Secondary**: Neutral grays
- **Success**: Green tones
- **Warning**: Orange/yellow tones
- **Destructive**: Red tones

### Responsive Breakpoints

- **Mobile**: < 768px
- **Tablet**: 768px - 1024px
- **Desktop**: > 1024px

## 🔌 API Integration

The frontend integrates with OpenProject API v3 using HAL+JSON format:

- Full TypeScript types for API responses
- Axios-based HTTP client
- Automatic CSRF token handling
- Request/response interceptors
- Error normalization

### Example API Usage

```typescript
import { apiClient } from '@/lib/api-client'

// Get work packages
const workPackages = await apiClient.workPackages.list({
  offset: 0,
  pageSize: 20,
  sortBy: '[["updatedAt", "desc"]]'
})

// Get current user
const user = await apiClient.auth.getCurrentUser()
```

## 📦 State Management

- **TanStack Query** for server state (API data)
- **Zustand** for client state (UI state, user preferences)
- **React Context** for theme and auth

## 🔐 Authentication

Authentication is handled via:

- Session-based auth (existing OpenProject auth)
- CSRF token protection
- Automatic redirect to login on 401

## ♿ Accessibility

- Semantic HTML
- ARIA attributes where needed
- Keyboard navigation support
- Screen reader friendly
- Focus management
- Minimum touch target sizes

## 📱 PWA Features

- Offline support
- App manifest
- Service worker
- Installable on mobile devices
- App-like experience

## 🚧 Roadmap

- [x] Project structure and build setup
- [x] Mobile-first UI components
- [x] Responsive navigation
- [x] Work packages list view
- [x] API client integration
- [ ] Authentication flow
- [ ] Work package detail view
- [ ] Create/edit work packages
- [ ] Projects management
- [ ] Calendar view
- [ ] Real-time notifications
- [ ] Offline support
- [ ] Dark mode
- [ ] Internationalization (i18n)
- [ ] Comprehensive test coverage
- [ ] Performance optimization

## 🤝 Contributing

1. Follow the existing code style
2. Write tests for new features
3. Ensure all tests pass
4. Use semantic commit messages
5. Keep mobile-first in mind

## 📄 License

Same as OpenProject main repository.
