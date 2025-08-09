import React from "react";
import { BrowserRouter, Routes as RouterRoutes, Route } from "react-router-dom";
import { AuthProvider } from "./contexts/AuthContext";
import { Header } from "./components/common/Header";
import ErrorBoundary from './components/ErrorBoundary';
import ScrollToTop from './components/ScrollToTop';

// Import all pages
import HomePage from "./pages/homepage";
import TopicHubsPage from "./pages/topic-hubs";
import CommunityFeedPage from "./pages/community-feed";
import ArticleStudioPage from "./pages/article-studio";
import WriterProfilesPage from "./pages/writer-profiles";
import AuthPage from "./pages/auth";
import DashboardPage from "./pages/dashboard";
import NotFound from "./pages/NotFound";

const Routes = () => {
  return (
    <BrowserRouter>
      <AuthProvider>
        <ErrorBoundary>
          <ScrollToTop />
          <div className="min-h-screen bg-gray-50">
            <Header />
            <RouterRoutes>
              <Route path="/" element={<HomePage />} />
              <Route path="/explore" element={<CommunityFeedPage />} />
              <Route path="/topics" element={<TopicHubsPage />} />
              <Route path="/writers" element={<WriterProfilesPage />} />
              <Route path="/write" element={<ArticleStudioPage />} />
              <Route path="/write/:id" element={<ArticleStudioPage />} />
              <Route path="/auth" element={<AuthPage />} />
              <Route path="/dashboard" element={<DashboardPage />} />
              <Route path="/dashboard/:tab" element={<DashboardPage />} />
              <Route path="*" element={<NotFound />} />
            </RouterRoutes>
          </div>
        </ErrorBoundary>
      </AuthProvider>
    </BrowserRouter>
  );
};

export default Routes;