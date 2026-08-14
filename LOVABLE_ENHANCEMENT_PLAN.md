# 🚀 Vishleshan UI Enhancement Master Plan (Lovable.dev Edition)

> **Project:** Vishleshan — Multi-Agent Recruitment Intelligence Platform  
> **Tech Stack:** React 18, Vite 8, Tailwind CSS, Lucide React, Radix UI, TanStack Query, Zustand, Django REST Framework, Celery, Redis.  
> **Goal:** Modernize, modularize, and enhance 100% of pages, components, and user portals across the entire platform using [Lovable.dev](https://lovable.dev).

---

## 📑 Table of Contents
1. [Architecture & Workflow Overview](#1-architecture--workflow-overview)
2. [Phase 0: Design System & Token Foundation](#2-phase-0-design-system--token-foundation)
3. [Track 1: Landing, Marketing & Public Pages](#3-track-1-landing-marketing--public-pages)
4. [Track 2: Recruiter ATS & Intelligence Workspace](#4-track-2-recruiter-ats--intelligence-workspace)
5. [Track 3: Job Seeker Portal & AI Tools](#5-track-3-job-seeker-portal--ai-tools)
6. [Track 4: Developer SaaS API Portal](#6-track-4-developer-saas-api-portal)
7. [Track 5: Candidate Assessment & Testing Suite](#7-track-5-candidate-assessment--testing-suite)
8. [Track 6: Admin Moderation Dashboard](#8-track-6-admin-moderation-dashboard)
9. [Integration & Backend Wiring Guide](#9-integration--backend-wiring-guide)
10. [Progress Tracking Checklist](#10-progress-tracking-checklist)

---

# 1. Architecture & Workflow Overview

Vishleshan's frontend and Lovable use identical core foundations: **React 18 + Vite + Tailwind CSS + Lucide React + Radix UI**.

### The 4-Step Enhancement Loop for Every Component:

```
┌────────────────────────────────────────────────────────┐
│  Step 1: Copy Track Prompt into Lovable                │
│  Generate the polished UI component with mock data     │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────┐
│  Step 2: Export & Save to `frontend/src/components/`   │
│  Keep file naming clean & modular                      │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────┐
│  Step 3: Wire to Zustand Stores & `src/lib/api.js`     │
│  Replace mock data with TanStack Query hooks           │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────┐
│  Step 4: Verify with `npm run dev` & Mark Checklist   │
└────────────────────────────────────────────────────────┘
```

---

# 2. Phase 0: Design System & Token Foundation

Before generating pages, ensure your design tokens are unified.

### 2.1 Update `frontend/src/globals.css`
Paste these modern HSL semantic tokens into `globals.css`:

```css
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  :root {
    --background: 0 0% 100%;
    --foreground: 224 71% 4%;
    --card: 0 0% 100%;
    --card-foreground: 224 71% 4%;
    --popover: 0 0% 100%;
    --popover-foreground: 224 71% 4%;
    --primary: 221.2 83.2% 53.3%;
    --primary-foreground: 210 40% 98%;
    --secondary: 210 40% 96.1%;
    --secondary-foreground: 222.2 47.4% 11.2%;
    --muted: 210 40% 96.1%;
    --muted-foreground: 215.4 16.3% 46.9%;
    --accent: 210 40% 96.1%;
    --accent-foreground: 222.2 47.4% 11.2%;
    --destructive: 0 84.2% 60.2%;
    --destructive-foreground: 210 40% 98%;
    --border: 214.3 31.8% 91.4%;
    --input: 214.3 31.8% 91.4%;
    --ring: 221.2 83.2% 53.3%;
    --radius: 0.75rem;
    --success: 142.1 76.2% 36.3%;
    --warning: 38 92% 50%;
  }

  .dark {
    --background: 224 71% 4%;
    --foreground: 213 31% 91%;
    --card: 224 71% 6%;
    --card-foreground: 213 31% 91%;
    --popover: 224 71% 6%;
    --popover-foreground: 213 31% 91%;
    --primary: 217.2 91.2% 59.8%;
    --primary-foreground: 222.2 47.4% 11.2%;
    --secondary: 217.2 32.6% 17.5%;
    --secondary-foreground: 210 40% 98%;
    --muted: 217.2 32.6% 17.5%;
    --muted-foreground: 215 20.2% 65.1%;
    --accent: 217.2 32.6% 17.5%;
    --accent-foreground: 210 40% 98%;
    --destructive: 0 62.8% 30.6%;
    --destructive-foreground: 210 40% 98%;
    --border: 216 34% 17%;
    --input: 216 34% 17%;
    --ring: 224.3 76.3% 48%;
  }
}
```

### 2.2 Foundation Prompt for Lovable (Core UI Primitives)
Use this prompt in Lovable to generate standard shadcn/ui components in `frontend/src/components/ui/`:

```markdown
Create a collection of clean, accessible UI primitives in React + Tailwind CSS (using Radix UI):
1. Button (variants: default, secondary, outline, ghost, destructive, glass, gradient)
2. Card (CardHeader, CardTitle, CardDescription, CardContent, CardFooter)
3. Badge (variants: default, success, warning, destructive, outline, glow)
4. Dialog and Slide-over Sheet (smooth spring animations)
5. Tabs (TabList, TabTrigger, TabContent with animated indicator)
6. Avatar (with fallback initials and status dot)
7. Tooltip & Dropdown Menu
8. Global Command Palette (Cmd+K search modal)

Use semantic HSL tokens (bg-background, text-foreground, bg-card, border-border, bg-primary).
```

---

# 3. Track 1: Landing, Marketing & Public Pages

### Target Files:
* `frontend/src/pages/LandingPage.jsx`
* `frontend/src/components/Navbar.jsx`
* `frontend/src/components/AuthPage.jsx`
* `frontend/src/components/Footer.jsx`
* `frontend/src/pages/public/AboutPage.jsx`, `ContactPage.jsx`, `TermsPage.jsx`, `SupportPortalPage.jsx`

### Lovable Prompt 1.1: World-Class AI Recruitment Landing Page
```markdown
Create a stunning SaaS Landing Page for "Vishleshan" - Multi-Agent Recruitment Intelligence Platform.

Structure:
1. Floating Pill Header: Logo, links (Recruiters, Job Seekers, Developers, Pricing, Docs), Theme Toggle, and "Launch App" CTA.
2. Hero Section:
   - Badge: "✨ Powered by 12 Coordinated Gemini AI Agents"
   - Headline: "Autonomous Recruitment Intelligence at Scale"
   - Subtitle: "Semantic resume parsing, vector-based candidate matching, automated fraud protection, and AI mock interviews in one unified platform."
   - Dual Action Buttons: "Start Free ATS Trial" (Gradient glow) & "Explore Developer API" (Glass border).
   - Live Interactive Widget Preview: An interactive resume scanner card showing live parsing progress, ATS compatibility score (96%), skills radar graph, and a green "Authenticity Verified" shield.
3. Bento Grid - 12 Specialized AI Agents:
   - Interactive grid showcasing: Parsing Agent, ATS Normalizer, Matching Engine, Fraud & Scam Hunter, Mock Interviewer, JD Generator, Salary Predictor.
4. Live Scam & Fake Job Detector Simulation:
   - Interactive demo showing 6-point verification (Corporate domain check, salary realism, copied JD scan).
5. Dynamic Pricing Section: Monthly / Annual toggle (20% discount badge), Starter, Professional, and Enterprise tiers.
6. Testimonials Carousel & Interactive FAQ Accordion.
7. Footer with newsletter signup, status indicator, and navigation links.

Theme: Dark mode first with subtle glowing gradients, glassmorphism, Framer Motion animations.
```

### Lovable Prompt 1.2: Split-Screen Authentication Hub
```markdown
Create an authentication hub component ("AuthPage.jsx") supporting Login, Registration, Password Reset, and Role Selection.

Layout:
- Left Side (Visual Showcase):
  - Dark glassmorphism card with an animated terminal stream of AI agents parsing resumes in real time, animated trust badges, and recruiter testimonials.
- Right Side (Form Area):
  - Segmented control: "Recruiter" | "Job Seeker" | "Developer"
  - Social Auth buttons: Google & GitHub with native SVGs.
  - Divider: "Or continue with email"
  - Input fields: Email, Password (with eye toggle), Remember Me, Forgot Password link.
  - Submit Button with loading spinner state.
  - Terms of Service note.
```

---

# 4. Track 2: Recruiter ATS & Intelligence Workspace

### Target Files:
* `frontend/src/pages/DashboardLayout.jsx`
* `frontend/src/pages/DashboardHome.jsx`
* `frontend/src/pages/SessionWorkspacePage.jsx`
* `frontend/src/pages/NewSessionPage.jsx`
* `frontend/src/pages/SmartAnalyzerPage.jsx`
* `frontend/src/components/CandidateCard.jsx`

### Lovable Prompt 2.1: Modern ATS Dashboard & Sidebar Layout
```markdown
Create a Dashboard Layout component ("DashboardLayout.jsx") with collapsible sidebar and top header.

Sidebar Items:
- Logo & Workspace switcher dropdown (Company name + Plan badge)
- Nav Items: Overview (Home), Sessions / Jobs, Smart ATS Analyzer, AI Recruiter Rules, Candidate Pool, Team & Settings
- Bottom items: API Quota usage progress bar (e.g. 840/1000 resumes used), Theme Toggle, User Profile menu.

Header:
- Global Search Bar (with `Ctrl + K` / `Cmd + K` trigger badge)
- Notification Bell with unread counter popup
- "New Hiring Session" quick action button
- Active API Key pool status indicator (e.g. "🟢 5/5 AI Keys Active")
```

### Lovable Prompt 2.2: Modular Session Workspace & Kanban Board
```markdown
Create a comprehensive Recruiter Session Workspace component ("SessionWorkspace.jsx") with 3 switchable views:
1. Kanban Pipeline View:
   - Drag-and-drop columns: "Applied", "AI Screened (>80%)", "MCQ Round", "Coding Round", "Interview", "Hired", "Rejected".
   - Candidate card in columns showing: Candidate Name, Target Role, Match Score Pill (e.g., 94%), Verified Skill Badges, Fraud Shield (Safe/Flagged), and quick action menu.
2. Table / List View:
   - High-density data table with sorting by Match Score, Experience, ATS Score, and Fraud Risk.
   - Batch selection checkboxes (Batch Export PDF, Batch Email, Batch Move Stage).
3. Live Multi-Agent Execution Graph:
   - Visual horizontal node workflow showing: Resume Ingestion ➔ Normalization ➔ Vector Matching ➔ Fraud Check ➔ Inference.
   - Nodes pulse when running, show green check when done, and clicking any node opens a JSON debug inspection drawer.
4. Slide-Over Candidate Detail Sheet:
   - Opens on card click: Shows full resume preview, skill match radar chart (Recharts), ATS keyword analysis, and dynamic notes.
```

### Lovable Prompt 2.3: Smart ATS Resume vs JD Analyzer
```markdown
Create an instant ATS Diagnostic Analyzer component ("SmartAnalyzer.jsx").

Layout:
- Left Column: Dual upload dropzone (Drop Candidate Resume PDF + Paste Job Description Text).
- Action Button: "Run Deep ATS Multi-Agent Audit".
- Right Column (Results HUD):
  - ATS Compatibility Score Radial Speedometer (0 to 100).
  - Match Breakdown: Skills Match (92%), Experience Relevance (85%), Formatting & Parsing Quality (98%).
  - Missing Essential Keywords cloud (highlighted in red) vs Matched Keywords (highlighted in green).
  - Section-by-section audit checklist (Header, Summary, Experience, Education, Skills).
  - Action: "Download ATS Optimization Report PDF".
```

---

# 5. Track 3: Job Seeker Portal & AI Tools

### Target Files:
* `frontend/src/pages/JobsSearchPage.jsx`, `JobDetailsPage.jsx`, `JobsTrendsPage.jsx`
* `frontend/src/pages/user/ResumeEditor.jsx`, `ResumeBuilderLanding.jsx`
* `frontend/src/pages/user/MockInterviewPage.jsx`
* `frontend/src/pages/seeker/MyApplicationsPage.jsx`
* `frontend/src/components/VerificationModal.jsx`

### Lovable Prompt 3.1: Job Search & 6-Point Fraud Legitimacy Shield
```markdown
Create a Job Search & Detail experience with an AI Fraud Shield.

Components:
1. Job Search Bar: Keyword search, location selector, Remote only toggle, salary range slider, and experience level filters.
2. Job Listing Feed: Cards showing Job Title, Company, Logo, Verified Company badge, Salary, Match Score for user's profile, and Trust Score.
3. Job Detail View with "Job Legitimacy Shield HUD":
   - Trust Meter (0-100 score).
   - 6-point verification breakdown with pass/fail badges:
     * Corporate Domain & SSL Validity
     * Recruiter Email Domain (@company.com vs free webmail)
     * Salary Realism Benchmark vs Market Data
     * LinkedIn & Glassdoor Presence
     * Boilerplate / Copied Description Detection
     * Duplicate Postings Pattern Detection
   - "Apply Now (1-Click AI Match)" button.
```

### Lovable Prompt 3.2: Visual WYSIWYG AI Resume Builder
```markdown
Create a modern split-screen AI Resume Builder component ("ResumeEditor.jsx").

Layout:
- Left Column (Editor Accordion):
  - Personal Info, Work Experience, Education, Skills, Projects, Certifications.
  - "✨ AI Rewrite & Optimize" button on every experience bullet point.
- Right Column (Live Document Preview & ATS Speedometer):
  - Top Bar: Template selector (Modern, Minimalist, Executive, Tech), Theme color picker, and "Download PDF" button.
  - Real-time ATS Compatibility Dial (0-100) that recalculates as the user edits.
  - High-fidelity resume preview rendering in real time.
```

### Lovable Prompt 3.3: AI Mock Interview Room with Live Proctoring
```markdown
Create an interactive AI Mock Interview Room ("MockInterviewPage.jsx").

Features:
1. Video Viewfinder: Webcam feed with optional AI proctoring guide grid (Eye contact & face position indicator).
2. Live Audio Waveform visualizer displaying when AI speaks vs when Candidate speaks.
3. Live AI Question Card: Question text, role context, and countdown response timer.
4. Real-time Feedback Meters: Speaking pace (WPM), Clarity score, and Confidence level.
5. Action Controls: "Record Answer", "Pause", "Submit Response", "Next Question".
6. Post-Interview Report Modal: Comprehensive scorecard with strengths, areas of improvement, and model answers.
```

---

# 6. Track 4: Developer SaaS API Portal

### Target Files:
* `frontend/src/pages/developer/DeveloperLandingPage.jsx`
* `frontend/src/pages/developer/DeveloperDashboard.jsx`
* `frontend/src/pages/developer/DeveloperDocs.jsx`
* `frontend/src/pages/developer/DeveloperKeys.jsx`
* `frontend/src/pages/developer/DeveloperUsage.jsx`
* `frontend/src/pages/developer/DeveloperEmbed.jsx`

### Lovable Prompt 4.1: Developer API Documentation & Live Playground
```markdown
Create an interactive Developer API Portal and Playground component ("DeveloperDocs.jsx").

Features:
1. Dark Mode Stripe/Supabase-inspired layout.
2. Endpoint Navigation:
   - POST /api/v1/resumes/parse
   - POST /api/v1/match/candidate-to-job
   - POST /api/v1/fraud/verify-job
   - POST /api/v1/ats/score
3. Interactive Request Playground:
   - API Key input field
   - Request Body editor (JSON or File Upload)
   - "Send Test Request" button
4. Response Console:
   - Status code badge (200 OK, 401 Unauthorized, 429 Rate Limit)
   - Execution latency (e.g. 248ms)
   - Formatted JSON response tree with search and 1-click copy.
5. Multi-language Code Snippet Switcher: cURL, Python (requests), JavaScript (axios), Go, and PHP.
```

### Lovable Prompt 4.2: API Key Management & Real-Time Usage HUD
```markdown
Create an API Dashboard component ("DeveloperDashboard.jsx").

Features:
1. Overview Cards: Total API Calls this month, Average Latency, Success Rate (99.8%), Current Monthly Spend.
2. API Key Management Table:
   - Key Name, Masked Key (`vish_live_••••••••9a21`), Created Date, Last Used, Monthly Limit, Actions (Revoke, Roll Key, Copy).
   - "Generate New API Key" modal with granular permission scopes (read:resumes, write:match, admin:all).
3. Usage Analytics Charts:
   - Request volume over time (Area chart).
   - Latency percentiles p50 / p95 / p99 (Line chart).
   - Error breakdown (4xx vs 5xx).
```

---

# 7. Track 5: Candidate Assessment & Testing Suite

### Target Files:
* `frontend/src/pages/test/TestEntry.jsx`
* `frontend/src/pages/test/MCQRound.jsx`
* `frontend/src/pages/test/CodingRound.jsx`
* `frontend/src/pages/test/InterviewRound.jsx`
* `frontend/src/components/test/TestShell.jsx`

### Lovable Prompt 5.1: Coding Assessment Round & IDE Interface
```markdown
Create a full-screen Coding Assessment interface component ("CodingRound.jsx").

Layout:
- Top Header: Test Title, Round (2 of 3), Remaining Time Countdown Clock, Full-screen proctoring status indicator, "Submit Assessment" button.
- Left Panel (Problem Statement):
  - Problem Title, Difficulty Badge (Medium), Description, Input/Output formats, Example test cases with visual explanation, Constraints.
- Right Panel (IDE Workspace):
  - Language Selector (Python, JavaScript, Java, C++, Go).
  - Code Editor area with line numbers and syntax styling.
  - Bottom Tabbed Terminal:
    * "Test Cases" (Custom input runner & sample case status: Passed / Failed)
    * "Compiler Output" (Stdout & execution time in ms)
  - Action Buttons: "Run Code" and "Submit Solution".
```

---

# 8. Track 6: Admin Moderation Dashboard

### Target Files:
* `frontend/src/pages/admin/AdminDashboard.jsx`
* `frontend/src/pages/admin/AdminLogin.jsx`

### Lovable Prompt 6.1: High-Density Admin & Moderation Console
```markdown
Create an enterprise Admin Moderation Dashboard component ("AdminDashboard.jsx").

Features:
1. Platform Health Grid:
   - Active Gemini API Keys in rotation pool (e.g. 10/12 Operational).
   - Celery Queue Length & Worker Status.
   - Total Scans Today, Fraud Detections, Active Recruiter Sessions.
2. Tabbed Management Tables:
   - "Flagged Jobs Queue": List of scam listings detected by AI, trust score, flag reasons, "Approve" & "Takedown" buttons.
   - "User Management": Ban/Unban user modal, reset rate limits, adjust API tiers.
   - "AI Key Health": Real-time quota usage and failover history per Gemini key.
   - "Audit Logs": Filterable audit trail of all platform events.
```

---

# 9. Integration & Backend Wiring Guide

Connecting Lovable-generated components to your existing Django backend:

### Step 1: Keep `src/lib/api.js` as the Single Source of Truth
Never let Lovable hardcode mock `fetch()` calls in page logic. Always pass your API methods into props or use TanStack Query hooks.

```jsx
// frontend/src/pages/SessionWorkspacePage.jsx
import React from 'react';
import { useParams } from 'react-router-dom';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { sessionsAPI, candidatesAPI } from '../lib/api';

// Import your newly generated Lovable components:
import SessionKanbanView from '../components/workspace/SessionKanbanView';
import MultiAgentVisualizer from '../components/workspace/MultiAgentVisualizer';
import CandidateDetailSheet from '../components/workspace/CandidateDetailSheet';

export default function SessionWorkspacePage() {
  const { id: sessionId } = useParams();
  const queryClient = useQueryClient();

  const { data: sessionData, isLoading } = useQuery({
    queryKey: ['session', sessionId],
    queryFn: () => sessionsAPI.get(sessionId),
  });

  const { data: candidates = [] } = useQuery({
    queryKey: ['candidates', sessionId],
    queryFn: () => candidatesAPI.listBySession(sessionId),
  });

  const moveStageMutation = useMutation({
    mutationFn: ({ candidateId, stage }) => candidatesAPI.updateStage(candidateId, stage),
    onSuccess: () => queryClient.invalidateQueries(['candidates', sessionId]),
  });

  return (
    <div className="space-y-6 p-6">
      {/* 1. Live Multi-Agent Workflow Visualizer */}
      <MultiAgentVisualizer activeStage={sessionData?.current_pipeline_stage} />

      {/* 2. Kanban Board generated from Lovable */}
      <SessionKanbanView 
        candidates={candidates}
        onMoveStage={(id, stage) => moveStageMutation.mutate({ candidateId: id, stage })}
      />
    </div>
  );
}
```

---

# 10. Progress Tracking Checklist

Use this checklist to track your progress as you modernize each section:

### Phase 0: System Foundation
- [ ] Update `globals.css` with semantic HSL variables
- [ ] Generate standard UI primitives (`Button`, `Card`, `Badge`, `Dialog`, `Sheet`, `Tabs`, `Command`) in `src/components/ui/`

### Track 1: Landing & Auth
- [ ] `LandingPage.jsx` (Hero, Bento Grid, Pricing, Agent Showcase)
- [ ] `AuthPage.jsx` (Split-screen auth with live terminal preview)
- [ ] `Navbar.jsx` & `Footer.jsx`
- [ ] `AboutPage.jsx`, `ContactPage.jsx`, `SupportPortalPage.jsx`

### Track 2: Recruiter ATS Hub
- [ ] `DashboardLayout.jsx` & Collapsible `Sidebar.jsx`
- [ ] `DashboardHome.jsx` (Metrics HUD)
- [ ] `SessionWorkspacePage.jsx` (Kanban Pipeline + Table View)
- [ ] `MultiAgentVisualizer.jsx` (Live agent graph)
- [ ] `CandidateDetailSheet.jsx` (Slide-over drawer)
- [ ] `SmartAnalyzerPage.jsx` (ATS Speedometer & Keyword density)

### Track 3: Job Seeker Portal
- [ ] `JobsSearchPage.jsx` & `JobDetailsPage.jsx`
- [ ] `JobLegitimacyShield.jsx` (6-point fraud detection HUD)
- [ ] `ResumeEditor.jsx` (WYSIWYG split editor with live ATS score)
- [ ] `MockInterviewPage.jsx` (Webcam & audio waveform proctoring)
- [ ] `MyApplicationsPage.jsx`

### Track 4: Developer Portal
- [ ] `DeveloperLandingPage.jsx` & `DeveloperDashboard.jsx`
- [ ] `DeveloperDocs.jsx` (Interactive API Playground & cURL/Python generator)
- [ ] `DeveloperKeys.jsx` & `DeveloperUsage.jsx`
- [ ] `DeveloperEmbed.jsx` & `EmbedWidget.jsx`

### Track 5: Assessment Hub
- [ ] `TestShell.jsx` (Proctoring & full-screen lock alert)
- [ ] `MCQRound.jsx` (Question matrix & timer)
- [ ] `CodingRound.jsx` (IDE, syntax highlighting & test case runner)
- [ ] `InterviewRound.jsx` (AI video interviewer room)

### Track 6: Admin Dashboard
- [ ] `AdminDashboard.jsx` (API key rotation pool status, fraud moderation queue, user ban controls)

---
*Created for the Vishleshan platform.*
