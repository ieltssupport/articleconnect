-- Location: supabase/migrations/20250809204522_article_platform_complete.sql
-- Complete Article Publishing Platform Schema with Authentication, Social Features, and Admin Dashboard
-- Schema State: FRESH_PROJECT - Creating complete database structure

-- 1. EXTENSIONS AND TYPES
CREATE TYPE public.user_role AS ENUM ('user', 'moderator', 'admin');
CREATE TYPE public.article_status AS ENUM ('draft', 'published', 'archived', 'featured');
CREATE TYPE public.comment_status AS ENUM ('pending', 'approved', 'rejected');
CREATE TYPE public.notification_type AS ENUM ('like', 'comment', 'follow', 'article_published', 'mention');
CREATE TYPE public.report_status AS ENUM ('pending', 'reviewed', 'resolved', 'dismissed');
CREATE TYPE public.report_type AS ENUM ('spam', 'inappropriate', 'harassment', 'copyright', 'other');

-- 2. CORE USER SYSTEM (Foundation for all relationships)
CREATE TABLE public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id),
    email TEXT NOT NULL UNIQUE,
    username TEXT UNIQUE,
    full_name TEXT NOT NULL,
    bio TEXT,
    avatar_url TEXT,
    website TEXT,
    location TEXT,
    is_verified BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    role public.user_role DEFAULT 'user'::public.user_role,
    followers_count INTEGER DEFAULT 0,
    following_count INTEGER DEFAULT 0,
    articles_count INTEGER DEFAULT 0,
    total_likes_received INTEGER DEFAULT 0,
    join_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 3. CATEGORIES AND TAGS SYSTEM
CREATE TABLE public.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    slug TEXT NOT NULL UNIQUE,
    description TEXT,
    color TEXT DEFAULT '#6366f1',
    icon TEXT,
    articles_count INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE public.tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    slug TEXT NOT NULL UNIQUE,
    description TEXT,
    color TEXT DEFAULT '#10b981',
    usage_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 4. ARTICLES SYSTEM (Main content)
CREATE TABLE public.articles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    excerpt TEXT,
    content TEXT NOT NULL,
    featured_image TEXT,
    author_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    category_id UUID REFERENCES public.categories(id) ON DELETE SET NULL,
    status public.article_status DEFAULT 'draft'::public.article_status,
    is_featured BOOLEAN DEFAULT false,
    view_count INTEGER DEFAULT 0,
    like_count INTEGER DEFAULT 0,
    comment_count INTEGER DEFAULT 0,
    share_count INTEGER DEFAULT 0,
    read_time INTEGER, -- estimated read time in minutes
    seo_title TEXT,
    seo_description TEXT,
    published_at TIMESTAMPTZ,
    featured_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 5. ARTICLE-TAG RELATIONSHIPS (Many-to-many)
CREATE TABLE public.article_tags (
    article_id UUID REFERENCES public.articles(id) ON DELETE CASCADE,
    tag_id UUID REFERENCES public.tags(id) ON DELETE CASCADE,
    PRIMARY KEY (article_id, tag_id)
);

-- 6. SOCIAL FEATURES (Likes, Follows, Comments)
CREATE TABLE public.article_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    article_id UUID REFERENCES public.articles(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(article_id, user_id)
);

CREATE TABLE public.user_follows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    follower_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    following_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(follower_id, following_id),
    CHECK (follower_id != following_id)
);

CREATE TABLE public.comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    article_id UUID REFERENCES public.articles(id) ON DELETE CASCADE,
    author_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    parent_id UUID REFERENCES public.comments(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    status public.comment_status DEFAULT 'approved'::public.comment_status,
    like_count INTEGER DEFAULT 0,
    reply_count INTEGER DEFAULT 0,
    is_edited BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE public.comment_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    comment_id UUID REFERENCES public.comments(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(comment_id, user_id)
);

-- 7. BOOKMARKS AND READING LISTS
CREATE TABLE public.bookmarks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    article_id UUID REFERENCES public.articles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, article_id)
);

CREATE TABLE public.reading_lists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    is_public BOOLEAN DEFAULT false,
    articles_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE public.reading_list_articles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reading_list_id UUID REFERENCES public.reading_lists(id) ON DELETE CASCADE,
    article_id UUID REFERENCES public.articles(id) ON DELETE CASCADE,
    added_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(reading_list_id, article_id)
);

-- 8. NOTIFICATIONS SYSTEM
CREATE TABLE public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    actor_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    type public.notification_type NOT NULL,
    title TEXT NOT NULL,
    message TEXT,
    entity_id UUID, -- can reference articles, comments, etc.
    entity_type TEXT, -- 'article', 'comment', 'user', etc.
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 9. REPORTING AND MODERATION
CREATE TABLE public.reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    reported_user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    entity_id UUID NOT NULL, -- article_id, comment_id, etc.
    entity_type TEXT NOT NULL, -- 'article', 'comment', 'user'
    type public.report_type NOT NULL,
    reason TEXT NOT NULL,
    status public.report_status DEFAULT 'pending'::public.report_status,
    moderator_id UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    moderator_notes TEXT,
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 10. ANALYTICS AND VIEWS
CREATE TABLE public.article_views (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    article_id UUID REFERENCES public.articles(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    ip_address TEXT,
    user_agent TEXT,
    referrer TEXT,
    viewed_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(article_id, user_id, DATE(viewed_at)) -- One view per user per article per day
);

-- 11. ESSENTIAL INDEXES FOR PERFORMANCE
CREATE INDEX idx_user_profiles_username ON public.user_profiles(username);
CREATE INDEX idx_user_profiles_email ON public.user_profiles(email);
CREATE INDEX idx_user_profiles_role ON public.user_profiles(role);

CREATE INDEX idx_articles_author_id ON public.articles(author_id);
CREATE INDEX idx_articles_category_id ON public.articles(category_id);
CREATE INDEX idx_articles_status ON public.articles(status);
CREATE INDEX idx_articles_published_at ON public.articles(published_at);
CREATE INDEX idx_articles_is_featured ON public.articles(is_featured);
CREATE INDEX idx_articles_slug ON public.articles(slug);

CREATE INDEX idx_comments_article_id ON public.comments(article_id);
CREATE INDEX idx_comments_author_id ON public.comments(author_id);
CREATE INDEX idx_comments_parent_id ON public.comments(parent_id);
CREATE INDEX idx_comments_status ON public.comments(status);

CREATE INDEX idx_article_likes_article_id ON public.article_likes(article_id);
CREATE INDEX idx_article_likes_user_id ON public.article_likes(user_id);

CREATE INDEX idx_user_follows_follower_id ON public.user_follows(follower_id);
CREATE INDEX idx_user_follows_following_id ON public.user_follows(following_id);

CREATE INDEX idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX idx_notifications_is_read ON public.notifications(is_read);
CREATE INDEX idx_notifications_created_at ON public.notifications(created_at);

CREATE INDEX idx_article_views_article_id ON public.article_views(article_id);
CREATE INDEX idx_article_views_viewed_at ON public.article_views(viewed_at);

-- 12. ENABLE ROW LEVEL SECURITY
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.article_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.article_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comment_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookmarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reading_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reading_list_articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.article_views ENABLE ROW LEVEL SECURITY;

-- 13. RLS POLICIES USING CORRECTED PATTERNS

-- Pattern 1: Core user table (user_profiles) - Simple only, no functions
CREATE POLICY "users_view_all_profiles"
ON public.user_profiles
FOR SELECT
TO public
USING (is_active = true);

CREATE POLICY "users_manage_own_profiles"
ON public.user_profiles
FOR ALL
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- Pattern 6A: Role-based access using auth metadata for admin functions
CREATE OR REPLACE FUNCTION public.is_admin_from_auth()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT EXISTS (
    SELECT 1 FROM auth.users au
    WHERE au.id = auth.uid() 
    AND (au.raw_user_meta_data->>'role' = 'admin' 
         OR au.raw_app_meta_data->>'role' = 'admin')
)
$$;

CREATE OR REPLACE FUNCTION public.is_moderator_or_admin_from_auth()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT EXISTS (
    SELECT 1 FROM auth.users au
    WHERE au.id = auth.uid() 
    AND (au.raw_user_meta_data->>'role' IN ('admin', 'moderator')
         OR au.raw_app_meta_data->>'role' IN ('admin', 'moderator'))
)
$$;

-- Categories: Public read, admin manage
CREATE POLICY "public_can_read_active_categories"
ON public.categories
FOR SELECT
TO public
USING (is_active = true);

CREATE POLICY "admin_manage_categories"
ON public.categories
FOR ALL
TO authenticated
USING (public.is_admin_from_auth())
WITH CHECK (public.is_admin_from_auth());

-- Tags: Public read, authenticated create/update
CREATE POLICY "public_can_read_tags"
ON public.tags
FOR SELECT
TO public
USING (true);

CREATE POLICY "authenticated_manage_tags"
ON public.tags
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Articles: Public read published, author manage own
CREATE POLICY "public_can_read_published_articles"
ON public.articles
FOR SELECT
TO public
USING (status = 'published'::public.article_status);

CREATE POLICY "authors_manage_own_articles"
ON public.articles
FOR ALL
TO authenticated
USING (author_id = auth.uid())
WITH CHECK (author_id = auth.uid());

CREATE POLICY "admin_manage_all_articles"
ON public.articles
FOR ALL
TO authenticated
USING (public.is_moderator_or_admin_from_auth())
WITH CHECK (public.is_moderator_or_admin_from_auth());

-- Article Tags: Public read, authenticated manage
CREATE POLICY "public_can_read_article_tags"
ON public.article_tags
FOR SELECT
TO public
USING (true);

-- Pattern 7: Complex access for article tags through article ownership
CREATE OR REPLACE FUNCTION public.can_manage_article_tags(p_article_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT EXISTS (
    SELECT 1 FROM public.articles a
    WHERE a.id = p_article_id 
    AND (a.author_id = auth.uid() OR (
        SELECT public.is_moderator_or_admin_from_auth()
    ))
)
$$;

CREATE POLICY "authors_manage_article_tags"
ON public.article_tags
FOR ALL
TO authenticated
USING (public.can_manage_article_tags(article_id))
WITH CHECK (public.can_manage_article_tags(article_id));

-- Article Likes: Pattern 2 - Simple user ownership
CREATE POLICY "users_manage_own_article_likes"
ON public.article_likes
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- User Follows: Pattern 2 - Simple user ownership
CREATE POLICY "users_manage_own_follows"
ON public.user_follows
FOR ALL
TO authenticated
USING (follower_id = auth.uid())
WITH CHECK (follower_id = auth.uid());

CREATE POLICY "public_can_view_follows"
ON public.user_follows
FOR SELECT
TO public
USING (true);

-- Comments: Public read approved, user manage own
CREATE POLICY "public_can_read_approved_comments"
ON public.comments
FOR SELECT
TO public
USING (status = 'approved'::public.comment_status);

CREATE POLICY "users_manage_own_comments"
ON public.comments
FOR ALL
TO authenticated
USING (author_id = auth.uid())
WITH CHECK (author_id = auth.uid());

CREATE POLICY "moderators_manage_comments"
ON public.comments
FOR ALL
TO authenticated
USING (public.is_moderator_or_admin_from_auth())
WITH CHECK (public.is_moderator_or_admin_from_auth());

-- Comment Likes: Pattern 2 - Simple user ownership
CREATE POLICY "users_manage_own_comment_likes"
ON public.comment_likes
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Bookmarks: Pattern 2 - Simple user ownership
CREATE POLICY "users_manage_own_bookmarks"
ON public.bookmarks
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Reading Lists: Mixed access (public read if public, user manage own)
CREATE POLICY "public_can_read_public_reading_lists"
ON public.reading_lists
FOR SELECT
TO public
USING (is_public = true);

CREATE POLICY "users_view_own_reading_lists"
ON public.reading_lists
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

CREATE POLICY "users_manage_own_reading_lists"
ON public.reading_lists
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Reading List Articles: Complex access through list ownership
CREATE OR REPLACE FUNCTION public.can_access_reading_list_articles(p_reading_list_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT EXISTS (
    SELECT 1 FROM public.reading_lists rl
    WHERE rl.id = p_reading_list_id 
    AND (rl.user_id = auth.uid() OR rl.is_public = true)
)
$$;

CREATE POLICY "reading_list_access_control"
ON public.reading_list_articles
FOR ALL
TO authenticated
USING (public.can_access_reading_list_articles(reading_list_id))
WITH CHECK (public.can_access_reading_list_articles(reading_list_id));

-- Notifications: Pattern 2 - Simple user ownership
CREATE POLICY "users_manage_own_notifications"
ON public.notifications
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Reports: User create own, admin/moderator manage all
CREATE POLICY "users_create_reports"
ON public.reports
FOR INSERT
TO authenticated
WITH CHECK (reporter_id = auth.uid());

CREATE POLICY "users_view_own_reports"
ON public.reports
FOR SELECT
TO authenticated
USING (reporter_id = auth.uid());

CREATE POLICY "moderators_manage_reports"
ON public.reports
FOR ALL
TO authenticated
USING (public.is_moderator_or_admin_from_auth())
WITH CHECK (public.is_moderator_or_admin_from_auth());

-- Article Views: Pattern 2 - Simple user ownership (for analytics)
CREATE POLICY "users_manage_own_article_views"
ON public.article_views
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

CREATE POLICY "admin_view_all_analytics"
ON public.article_views
FOR SELECT
TO authenticated
USING (public.is_admin_from_auth());

-- 14. HELPER FUNCTIONS AND TRIGGERS

-- Auto-create user profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public.user_profiles (id, email, full_name, username, role)
  VALUES (
    NEW.id, 
    NEW.email, 
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'role', 'user')::public.user_role
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Update article stats on like/comment
CREATE OR REPLACE FUNCTION public.update_article_like_count()
RETURNS TRIGGER
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.articles 
        SET like_count = like_count + 1
        WHERE id = NEW.article_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.articles 
        SET like_count = like_count - 1
        WHERE id = OLD.article_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER trigger_update_article_like_count
    AFTER INSERT OR DELETE ON public.article_likes
    FOR EACH ROW EXECUTE FUNCTION public.update_article_like_count();

CREATE OR REPLACE FUNCTION public.update_article_comment_count()
RETURNS TRIGGER
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.articles 
        SET comment_count = comment_count + 1
        WHERE id = NEW.article_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.articles 
        SET comment_count = comment_count - 1
        WHERE id = OLD.article_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER trigger_update_article_comment_count
    AFTER INSERT OR DELETE ON public.comments
    FOR EACH ROW EXECUTE FUNCTION public.update_article_comment_count();

-- Update user follow counts
CREATE OR REPLACE FUNCTION public.update_follow_counts()
RETURNS TRIGGER
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Increase follower count for following user
        UPDATE public.user_profiles 
        SET followers_count = followers_count + 1
        WHERE id = NEW.following_id;
        
        -- Increase following count for follower user
        UPDATE public.user_profiles 
        SET following_count = following_count + 1
        WHERE id = NEW.follower_id;
        
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        -- Decrease follower count for following user
        UPDATE public.user_profiles 
        SET followers_count = followers_count - 1
        WHERE id = OLD.following_id;
        
        -- Decrease following count for follower user
        UPDATE public.user_profiles 
        SET following_count = following_count - 1
        WHERE id = OLD.follower_id;
        
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER trigger_update_follow_counts
    AFTER INSERT OR DELETE ON public.user_follows
    FOR EACH ROW EXECUTE FUNCTION public.update_follow_counts();

-- 15. STORAGE BUCKETS FOR FILE UPLOADS

-- Public bucket for article images, user avatars (publicly viewable)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'article-images',
    'article-images',
    true,
    10485760, -- 10MB limit
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/jpg', 'image/gif']
);

-- Private bucket for user documents, drafts
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'user-files',
    'user-files',
    false,
    52428800, -- 50MB limit
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/jpg', 'image/gif', 'application/pdf', 'text/plain', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document']
);

-- Storage RLS Policies

-- Article images: Public read, authenticated upload
CREATE POLICY "public_can_view_article_images"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'article-images');

CREATE POLICY "authenticated_users_upload_article_images"
ON storage.objects  
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'article-images');

CREATE POLICY "owners_manage_article_images"
ON storage.objects
FOR UPDATE, DELETE
TO authenticated
USING (bucket_id = 'article-images' AND owner = auth.uid());

-- User files: Private access only
CREATE POLICY "users_view_own_files"
ON storage.objects
FOR SELECT
TO authenticated
USING (bucket_id = 'user-files' AND owner = auth.uid());

CREATE POLICY "users_upload_own_files" 
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'user-files' 
    AND owner = auth.uid()
    AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "users_manage_own_files"
ON storage.objects
FOR UPDATE, DELETE
TO authenticated
USING (bucket_id = 'user-files' AND owner = auth.uid());

-- 16. COMPLETE MOCK DATA WITH REALISTIC CONTENT

DO $$
DECLARE
    admin_id UUID := gen_random_uuid();
    john_id UUID := gen_random_uuid();
    jane_id UUID := gen_random_uuid();
    alex_id UUID := gen_random_uuid();
    
    tech_cat_id UUID := gen_random_uuid();
    lifestyle_cat_id UUID := gen_random_uuid();
    business_cat_id UUID := gen_random_uuid();
    
    react_tag_id UUID := gen_random_uuid();
    javascript_tag_id UUID := gen_random_uuid();
    productivity_tag_id UUID := gen_random_uuid();
    startup_tag_id UUID := gen_random_uuid();
    
    article1_id UUID := gen_random_uuid();
    article2_id UUID := gen_random_uuid();
    article3_id UUID := gen_random_uuid();
    article4_id UUID := gen_random_uuid();
    
    comment1_id UUID := gen_random_uuid();
    comment2_id UUID := gen_random_uuid();
    
    reading_list_id UUID := gen_random_uuid();
BEGIN
    -- Create auth users with complete field structure
    INSERT INTO auth.users (
        id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
        created_at, updated_at, raw_user_meta_data, raw_app_meta_data,
        is_sso_user, is_anonymous, confirmation_token, confirmation_sent_at,
        recovery_token, recovery_sent_at, email_change_token_new, email_change,
        email_change_sent_at, email_change_token_current, email_change_confirm_status,
        reauthentication_token, reauthentication_sent_at, phone, phone_change,
        phone_change_token, phone_change_sent_at
    ) VALUES
        (admin_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'admin@articleconnect.com', crypt('admin123', gen_salt('bf', 10)), now(), now(), now(),
         '{"full_name": "Admin User", "username": "admin", "role": "admin"}'::jsonb, 
         '{"provider": "email", "providers": ["email"]}'::jsonb,
         false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null),
        (john_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'john@articleconnect.com', crypt('password123', gen_salt('bf', 10)), now(), now(), now(),
         '{"full_name": "John Writer", "username": "johnwriter", "role": "user"}'::jsonb, 
         '{"provider": "email", "providers": ["email"]}'::jsonb,
         false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null),
        (jane_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'jane@articleconnect.com', crypt('password123', gen_salt('bf', 10)), now(), now(), now(),
         '{"full_name": "Jane Blogger", "username": "janeblogger", "role": "user"}'::jsonb, 
         '{"provider": "email", "providers": ["email"]}'::jsonb,
         false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null),
        (alex_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'alex@articleconnect.com', crypt('password123', gen_salt('bf', 10)), now(), now(), now(),
         '{"full_name": "Alex Developer", "username": "alexdev", "role": "user"}'::jsonb, 
         '{"provider": "email", "providers": ["email"]}'::jsonb,
         false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null);

    -- Create categories
    INSERT INTO public.categories (id, name, slug, description, color, icon) VALUES
        (tech_cat_id, 'Technology', 'technology', 'Latest in tech, programming, and digital innovation', '#3b82f6', 'Laptop'),
        (lifestyle_cat_id, 'Lifestyle', 'lifestyle', 'Health, wellness, and personal development', '#10b981', 'Heart'),
        (business_cat_id, 'Business', 'business', 'Entrepreneurship, startups, and business strategies', '#f59e0b', 'Briefcase');

    -- Create tags
    INSERT INTO public.tags (id, name, slug, description, color) VALUES
        (react_tag_id, 'React', 'react', 'React.js library and ecosystem', '#61dafb'),
        (javascript_tag_id, 'JavaScript', 'javascript', 'JavaScript programming language', '#f7df1e'),
        (productivity_tag_id, 'Productivity', 'productivity', 'Tips and tools for better productivity', '#8b5cf6'),
        (startup_tag_id, 'Startup', 'startup', 'Startup culture and entrepreneurship', '#ec4899');

    -- Create articles
    INSERT INTO public.articles (
        id, title, slug, excerpt, content, author_id, category_id, status, 
        is_featured, view_count, like_count, published_at
    ) VALUES
        (article1_id, 
         'Getting Started with React Hooks: A Complete Guide',
         'getting-started-react-hooks-complete-guide',
         'Learn how to use React Hooks to build modern, functional components with state management and side effects.',
         E'# Getting Started with React Hooks\n\nReact Hooks have revolutionized the way we write React components. In this comprehensive guide, we will explore the most commonly used hooks and how they can simplify your code.\n\n## What are React Hooks?\n\nHooks are functions that let you use state and other React features in functional components. They were introduced in React 16.8 and have since become the preferred way to write React components.\n\n## useState Hook\n\nThe useState hook allows you to add state to functional components:\n\n```jsx\nimport React, { useState } from "react";\n\nfunction Counter() {\n  const [count, setCount] = useState(0);\n  \n  return (\n    <div>\n      <p>You clicked {count} times</p>\n      <button onClick={() => setCount(count + 1)}>\n        Click me\n      </button>\n    </div>\n  );\n}\n```\n\n## useEffect Hook\n\nThe useEffect hook lets you perform side effects in functional components:\n\n```jsx\nimport React, { useState, useEffect } from "react";\n\nfunction UserProfile({ userId }) {\n  const [user, setUser] = useState(null);\n  \n  useEffect(() => {\n    fetchUser(userId).then(setUser);\n  }, [userId]);\n  \n  return user ? <div>{user.name}</div> : <div>Loading...</div>;\n}\n```\n\n## Best Practices\n\n1. Always use the dependency array in useEffect\n2. Keep hooks at the top level of your components\n3. Use custom hooks to share logic between components\n\n## Conclusion\n\nReact Hooks make it easier to write clean, reusable components. Start incorporating them into your React applications today!',
         john_id, tech_cat_id, 'published'::public.article_status,
         true, 1250, 0, NOW() - INTERVAL '2 days'),
         
        (article2_id,
         'Building a Productive Morning Routine That Actually Works',
         'building-productive-morning-routine-actually-works',
         'Discover science-backed strategies to create a morning routine that sets you up for success throughout the day.',
         E'# Building a Productive Morning Routine\n\nYour morning routine sets the tone for your entire day. After years of experimentation and research, here is what actually works.\n\n## The Science Behind Morning Routines\n\nResearch shows that having a consistent morning routine can:\n- Reduce decision fatigue\n- Improve mental clarity\n- Increase productivity throughout the day\n- Reduce stress and anxiety\n\n## The 5 Essential Elements\n\n### 1. Wake Up at a Consistent Time\nYour body thrives on routine. Pick a wake-up time and stick to it, even on weekends.\n\n### 2. Hydrate Immediately\nAfter 7-8 hours without water, your body needs hydration. Start with a large glass of water.\n\n### 3. Move Your Body\nEven 10 minutes of stretching or light exercise can boost your energy and mood.\n\n### 4. Practice Mindfulness\nWhether it is meditation, journaling, or simply sitting quietly, give your mind time to center itself.\n\n### 5. Plan Your Day\nSpend 5 minutes reviewing your priorities and setting intentions for the day.\n\n## Common Mistakes to Avoid\n\n- Checking your phone immediately upon waking\n- Trying to change too much at once\n- Being too rigid - allow for flexibility\n- Comparing your routine to others\n\n## Making It Stick\n\nStart small. Pick just one element and do it consistently for a week. Then gradually add more elements.\n\nRemember, the best morning routine is the one you will actually follow. Customize these suggestions to fit your lifestyle and preferences.',
         jane_id, lifestyle_cat_id, 'published'::public.article_status,
         false, 890, 0, NOW() - INTERVAL '1 day'),
         
        (article3_id,
         'The Future of Remote Work: Trends and Predictions for 2024',
         'future-remote-work-trends-predictions-2024',
         'Explore the evolving landscape of remote work and what businesses should prepare for in the coming years.',
         E'# The Future of Remote Work: 2024 and Beyond\n\nThe pandemic accelerated remote work adoption, but what does the future hold? Let us examine the trends shaping the remote work landscape.\n\n## Current State of Remote Work\n\nAs of 2024, approximately 35% of workers who can work remotely are doing so full-time, with another 25% working in hybrid arrangements.\n\n## Key Trends to Watch\n\n### 1. Hybrid-First Policies\nCompanies are moving beyond "remote-friendly" to "hybrid-first" policies that prioritize flexibility.\n\n### 2. Advanced Collaboration Tools\nAI-powered meeting assistants, virtual reality workspaces, and real-time collaboration platforms are becoming mainstream.\n\n### 3. Focus on Results, Not Hours\nOutput-based performance metrics are replacing traditional time-based measurements.\n\n### 4. Digital Nomad Programs\nMore companies are offering formal digital nomad programs and location-independent roles.\n\n## Challenges and Solutions\n\n### Maintaining Company Culture\n**Challenge**: Building connections remotely\n**Solution**: Regular virtual social events, mentorship programs, and intentional culture-building activities\n\n### Managing Different Time Zones\n**Challenge**: Coordinating across global teams\n**Solution**: Asynchronous communication tools and clearly defined core collaboration hours\n\n### Employee Wellbeing\n**Challenge**: Preventing burnout and isolation\n**Solution**: Mental health support, virtual wellness programs, and clear boundaries\n\n## Predictions for 2025 and Beyond\n\n1. **50% of knowledge work will be fully remote** by 2025\n2. **AI assistants will handle routine communications**, freeing humans for creative work\n3. **Virtual reality meetings** will become as common as video calls\n4. **Skills-based hiring** will completely replace location-based recruiting\n\n## Preparing Your Business\n\nTo thrive in this remote-first future:\n- Invest in robust digital infrastructure\n- Develop strong asynchronous communication practices\n- Focus on outcome-based performance metrics\n- Prioritize employee experience and wellbeing\n\nThe future of work is not just remote—it is flexible, inclusive, and human-centered.',
         alex_id, business_cat_id, 'published'::public.article_status,
         true, 2100, 0, NOW() - INTERVAL '3 hours'),
         
        (article4_id,
         'My Journey from Corporate Employee to Successful Entrepreneur',
         'journey-corporate-employee-successful-entrepreneur',
         'A personal story of leaving the corporate world to build a thriving business, including the challenges and lessons learned.',
         E'# From Corporate Cubicle to Entrepreneurial Freedom\n\nTwo years ago, I was sitting in a gray cubicle, staring at spreadsheets, and dreaming of something more. Today, I run a successful business that generates seven figures annually. Here is my story.\n\n## The Corporate Years\n\nI spent eight years climbing the corporate ladder at a Fortune 500 company. The pay was good, the benefits were solid, but something was missing. I felt like a small cog in a massive machine.\n\n### The Breaking Point\n\nIt was during a particularly soul-crushing quarterly review that I realized I needed to make a change. My manager criticized me for being "too innovative" and "not following established processes." That is when I knew it was time.\n\n## Making the Leap\n\n### Step 1: Building a Safety Net\nI did not quit immediately. Instead, I:\n- Saved six months of expenses\n- Built a network in my target industry\n- Developed my business idea on nights and weekends\n- Created a minimum viable product\n\n### Step 2: Testing the Waters\nBefore leaving my job, I validated my business idea by:\n- Conducting customer interviews\n- Running small pilot programs\n- Building an email list of potential customers\n- Securing my first three clients\n\n### Step 3: The Transition\nI negotiated with my employer to work part-time for three months, giving me a gradual transition and some income while I grew my business.\n\n## The First Year Challenges\n\n### Financial Stress\nEven with savings, the irregular income was stressful. Some months I made more than my corporate salary, others I made nothing.\n\n### Impostor Syndrome\n"Who am I to run a business?" was a constant thought. I overcame this by focusing on the value I provided to clients.\n\n### Loneliness\nWorking alone was isolating. I joined co-working spaces and entrepreneur meetups to combat this.\n\n### Time Management\nWithout a structured office environment, I struggled with productivity. I had to develop new systems and habits.\n\n## What Made the Difference\n\n### 1. Customer-First Mindset\nI obsessed over solving real problems for real people, not just making money.\n\n### 2. Continuous Learning\nI invested heavily in courses, books, and mentorship to develop business skills.\n\n### 3. Building Systems\nAs I grew, I documented processes and hired help to avoid burnout.\n\n### 4. Resilience\nEvery "no" brought me closer to a "yes." Rejection became fuel for improvement.\n\n## Year Two and Beyond\n\nBy year two, I had:\n- Generated over $1.2 million in revenue\n- Hired a team of five employees\n- Expanded into three new markets\n- Achieved work-life balance (most days!)\n\n## Lessons Learned\n\n1. **Start before you are ready** - You will never feel 100% prepared\n2. **Focus on cash flow** - Revenue is vanity, profit is sanity, cash flow is reality\n3. **Build relationships** - Your network is your net worth\n4. **Embrace failure** - Every failure is a lesson in disguise\n5. **Take care of yourself** - Your business cannot be healthy if you are not\n\n## Should You Make the Leap?\n\nEntrepreneurship is not for everyone, and that is okay. But if you:\n- Have a solution to a real problem\n- Are willing to work harder than you ever have\n- Can handle uncertainty and rejection\n- Have a financial safety net\n\nThen maybe it is time to take the leap.\n\n## Final Thoughts\n\nThe journey from employee to entrepreneur has been the most challenging and rewarding experience of my life. It is not just about building a business—it is about building yourself.\n\nIf you are considering entrepreneurship, start small, start now, and remember: every expert was once a beginner.',
         jane_id, business_cat_id, 'draft'::public.article_status,
         false, 0, 0, null);

    -- Create article-tag relationships
    INSERT INTO public.article_tags (article_id, tag_id) VALUES
        (article1_id, react_tag_id),
        (article1_id, javascript_tag_id),
        (article2_id, productivity_tag_id),
        (article3_id, productivity_tag_id),
        (article4_id, startup_tag_id);

    -- Create user follows
    INSERT INTO public.user_follows (follower_id, following_id) VALUES
        (jane_id, john_id),
        (alex_id, john_id),
        (john_id, jane_id),
        (alex_id, jane_id);

    -- Create article likes
    INSERT INTO public.article_likes (article_id, user_id) VALUES
        (article1_id, jane_id),
        (article1_id, alex_id),
        (article2_id, john_id),
        (article2_id, alex_id),
        (article3_id, john_id),
        (article3_id, jane_id);

    -- Create comments
    INSERT INTO public.comments (id, article_id, author_id, content, status) VALUES
        (comment1_id, article1_id, jane_id, 
         'Excellent tutorial! The code examples are really helpful. I have been struggling with useEffect dependencies and this cleared up a lot of confusion.',
         'approved'::public.comment_status),
        (comment2_id, article2_id, alex_id,
         'I implemented this morning routine and it has completely transformed my productivity. The key insight about decision fatigue was a game-changer for me.',
         'approved'::public.comment_status);

    -- Create reply to first comment
    INSERT INTO public.comments (article_id, author_id, parent_id, content, status) VALUES
        (article1_id, john_id, comment1_id,
         'Thanks Jane! I am glad it helped. useEffect dependencies can be tricky at first, but once you understand the concept it becomes second nature.',
         'approved'::public.comment_status);

    -- Create bookmarks
    INSERT INTO public.bookmarks (user_id, article_id) VALUES
        (jane_id, article3_id),
        (alex_id, article1_id),
        (alex_id, article2_id);

    -- Create reading list
    INSERT INTO public.reading_lists (id, user_id, name, description, is_public) VALUES
        (reading_list_id, alex_id, 'Web Development Resources', 
         'Collection of articles about modern web development practices and tools',
         true);

    -- Add articles to reading list
    INSERT INTO public.reading_list_articles (reading_list_id, article_id) VALUES
        (reading_list_id, article1_id);

    -- Create notifications
    INSERT INTO public.notifications (user_id, actor_id, type, title, message, entity_id, entity_type) VALUES
        (john_id, jane_id, 'like'::public.notification_type, 
         'New like on your article', 
         'Jane Blogger liked your article "Getting Started with React Hooks"',
         article1_id, 'article'),
        (john_id, jane_id, 'comment'::public.notification_type,
         'New comment on your article',
         'Jane Blogger commented on "Getting Started with React Hooks"',
         comment1_id, 'comment'),
        (jane_id, alex_id, 'follow'::public.notification_type,
         'New follower',
         'Alex Developer started following you',
         alex_id, 'user');

    -- Create article views for analytics
    INSERT INTO public.article_views (article_id, user_id, viewed_at) VALUES
        (article1_id, jane_id, NOW() - INTERVAL '2 days'),
        (article1_id, alex_id, NOW() - INTERVAL '1 day'),
        (article2_id, john_id, NOW() - INTERVAL '1 day'),
        (article2_id, alex_id, NOW() - INTERVAL '12 hours'),
        (article3_id, john_id, NOW() - INTERVAL '6 hours'),
        (article3_id, jane_id, NOW() - INTERVAL '3 hours');

EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Foreign key error: %', SQLERRM;
    WHEN unique_violation THEN
        RAISE NOTICE 'Unique constraint error: %', SQLERRM;
    WHEN OTHERS THEN
        RAISE NOTICE 'Unexpected error: %', SQLERRM;
END $$;

-- 17. CLEANUP FUNCTION FOR DEVELOPMENT
CREATE OR REPLACE FUNCTION public.cleanup_demo_data()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    auth_user_ids_to_delete UUID[];
BEGIN
    -- Get auth user IDs first
    SELECT ARRAY_AGG(id) INTO auth_user_ids_to_delete
    FROM auth.users
    WHERE email LIKE '%@articleconnect.com';

    -- Delete in dependency order (children first, then auth.users last)
    DELETE FROM public.article_views WHERE user_id = ANY(auth_user_ids_to_delete);
    DELETE FROM public.notifications WHERE user_id = ANY(auth_user_ids_to_delete) OR actor_id = ANY(auth_user_ids_to_delete);
    DELETE FROM public.reading_list_articles WHERE reading_list_id IN (
        SELECT id FROM public.reading_lists WHERE user_id = ANY(auth_user_ids_to_delete)
    );
    DELETE FROM public.reading_lists WHERE user_id = ANY(auth_user_ids_to_delete);
    DELETE FROM public.bookmarks WHERE user_id = ANY(auth_user_ids_to_delete);
    DELETE FROM public.comment_likes WHERE user_id = ANY(auth_user_ids_to_delete);
    DELETE FROM public.comments WHERE author_id = ANY(auth_user_ids_to_delete);
    DELETE FROM public.article_likes WHERE user_id = ANY(auth_user_ids_to_delete);
    DELETE FROM public.user_follows WHERE follower_id = ANY(auth_user_ids_to_delete) OR following_id = ANY(auth_user_ids_to_delete);
    DELETE FROM public.article_tags WHERE article_id IN (
        SELECT id FROM public.articles WHERE author_id = ANY(auth_user_ids_to_delete)
    );
    DELETE FROM public.articles WHERE author_id = ANY(auth_user_ids_to_delete);
    DELETE FROM public.tags;
    DELETE FROM public.categories;
    DELETE FROM public.user_profiles WHERE id = ANY(auth_user_ids_to_delete);

    -- Delete auth.users last (after all references are removed)
    DELETE FROM auth.users WHERE id = ANY(auth_user_ids_to_delete);
    
    RAISE NOTICE 'Demo data cleanup completed successfully';
EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Foreign key constraint prevents deletion: %', SQLERRM;
    WHEN OTHERS THEN
        RAISE NOTICE 'Cleanup failed: %', SQLERRM;
END;
$$;