import React, { useState, useEffect, useRef } from "react";
import { useNavigate, Link } from "react-router-dom";
import { toast } from "react-hot-toast";
import { portalAuth } from "../../lib/portalApi";
import { usePortalAuthStore } from "../../stores/portalAuthStore";
import { Eye, EyeOff } from "lucide-react";

export default function DeveloperLoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();
  const { setAuth, initFromStorage, jwt } = usePortalAuthStore();
  const googleClientRef = useRef(null);

  useEffect(() => {
    const script = document.createElement("script");
    script.src = "https://accounts.google.com/gsi/client";
    script.async = true;
    script.defer = true;
    script.onload = () => {
      if (window.google) {
        googleClientRef.current = window.google.accounts.oauth2.initTokenClient({
          client_id: import.meta.env.VITE_GOOGLE_CLIENT_ID,
          scope: "openid email profile",
          callback: async (tokenResponse) => {
            if (tokenResponse && tokenResponse.access_token) {
              setLoading(true);
              try {
                const data = await portalAuth.googleLogin(tokenResponse.access_token);
                if (data.requires_profile_completion) {
                  localStorage.removeItem("portal_jwt");
                  localStorage.removeItem("portal_dev");
                  sessionStorage.setItem('temp_oauth_data', JSON.stringify({ role: 'developer', data }));
                  navigate('/auth/complete-profile');
                  return;
                }
                setAuth(data);
                toast.success("Signed in successfully with Google!");
                navigate("/developer/portal/dashboard");
              } catch (err) {
                toast.error(err.message || "Google login failed");
              } finally {
                setLoading(false);
              }
            }
          }
        });
      }
    };
    document.body.appendChild(script);

    initFromStorage();
    if (usePortalAuthStore.getState().jwt) {
      navigate("/developer/portal/dashboard");
    }
  }, [initFromStorage, navigate, setAuth]);

  const handleLogin = async (e) => {
    e.preventDefault();
    setLoading(true);
    try {
      const data = await portalAuth.login(email, password);
      setAuth(data);
      toast.success("Welcome back!");
      navigate("/developer/portal/dashboard");
    } catch (err) {
      toast.error(err.message || "Login failed");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center relative bg-bg overflow-hidden font-sans">
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_center,_var(--tw-gradient-stops))] from-gray-100 via-bg to-bg opacity-70"></div>
      
      <div className="w-full max-w-md bg-white rounded-3xl p-8 relative z-10 shadow-2xl shadow-gray-200/50 border border-gray-100 m-4">
        <div className="flex flex-col items-center mb-8">
          <span className="text-gray-500 text-[14px] font-medium mb-1">Developer Portal</span>
          <h1 className="text-3xl font-black tracking-tight text-accent">Between</h1>
        </div>

        <form onSubmit={handleLogin} className="flex flex-col gap-4">
          <div className="flex flex-col gap-1.5">
            <label className="text-sm font-semibold text-charcoal">Email Address</label>
            <input 
              type="email" 
              placeholder="developer@company.com" 
              value={email}
              onChange={e => setEmail(e.target.value)}
              className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-accent/20 focus:border-accent outline-none transition-all placeholder:text-gray-400 font-medium"
              required 
            />
          </div>

          <div className="flex flex-col gap-1.5">
            <div className="flex justify-between items-center">
              <label className="text-sm font-semibold text-charcoal">Password</label>
              <button type="button" onClick={() => navigate('/developer/forgot-password?type=developer')} className="text-xs text-gray-500 hover:text-accent font-medium">Forgot password?</button>
            </div>
            <div className="relative w-full">
              <input 
                type={showPassword ? "text" : "password"} 
                placeholder="••••••••" 
                value={password}
                onChange={e => setPassword(e.target.value)}
                className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-accent/20 focus:border-accent outline-none transition-all placeholder:text-gray-400 font-medium pr-12"
                required 
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-accent transition-colors"
              >
                {showPassword ? <EyeOff size={20} /> : <Eye size={20} />}
              </button>
            </div>
          </div>

          <button 
            type="submit" 
            disabled={loading}
            className="w-full mt-2 bg-accent text-white py-3.5 rounded-xl font-bold tracking-wide hover:bg-accent-dark transition-all shadow-md shadow-accent/20 hover:-translate-y-0.5 disabled:opacity-70 disabled:hover:translate-y-0"
          >
            {loading ? "Signing in..." : "Sign In"}
          </button>

          <div className="relative my-2 flex items-center justify-center">
            <div className="absolute inset-0 flex items-center">
              <div className="w-full border-t border-gray-200"></div>
            </div>
            <span className="relative px-3 bg-white text-xs font-semibold text-gray-400 uppercase tracking-widest">or</span>
          </div>

          <button 
            type="button" 
            disabled={loading}
            onClick={() => {
              if (googleClientRef.current) {
                googleClientRef.current.requestAccessToken();
              } else {
                toast.error("Google Auth is loading. Please try again in a moment.");
              }
            }}
            className="w-full flex items-center justify-center gap-2.5 bg-white border border-gray-200 text-charcoal py-3.5 rounded-xl font-bold tracking-wide hover:bg-gray-50 transition-all shadow-sm hover:-translate-y-0.5 disabled:opacity-70 disabled:hover:translate-y-0"
          >
            <svg viewBox="0 0 24 24" width="18" height="18" className="w-4.5 h-4.5">
              <path d="M21.35,11.1H12v2.7h5.38C17,14.93,15.76,15.9,14.15,16.5l2.2,2.2c2.6-2.4,4.1-5.9,4.1-10C22.45,12.3,22,11.6,21.35,11.1z" fill="#4285F4" />
              <path d="M12,20.45c2.6,0,4.8-.85,6.4-2.3l-2.2-2.2c-.85.6-2,1-3.3,1c-3.15,0-5.8-2.15-6.75-5.05L3.9,13.9A10.45,10.45,0,0,0,12,20.45z" fill="#34A853" />
              <path d="M5.25,12.1a6.4,6.4,0,0,1,0-3.8L3.05,6A10.45,10.45,0,0,0,3.05,16.2z" fill="#FBBC05" />
              <path d="M12,5.25c1.8,0,3.2.6,4.05,1.4l2-2A10.35,10.35,0,0,0,12,1.55a10.45,10.45,0,0,0-8.1,4.45L6.1,8.1C7.05,5.2,9.7,3.15,12,5.25z" fill="#EA4335" />
            </svg>
            <span>Sign In with Google</span>
          </button>

          <button 
            type="button" 
            disabled={loading}
            onClick={() => {
              const clientId = import.meta.env.VITE_GITHUB_CLIENT_ID;
              const redirectUri = encodeURIComponent(window.location.origin + '/auth/github/callback');
              window.location.href = `https://github.com/login/oauth/authorize?client_id=${clientId}&redirect_uri=${redirectUri}&scope=read:user,user:email&state=developer`;
            }}
            className="w-full flex items-center justify-center gap-2.5 bg-white border border-gray-200 text-charcoal py-3.5 rounded-xl font-bold tracking-wide hover:bg-gray-50 transition-all shadow-sm hover:-translate-y-0.5 disabled:opacity-70 disabled:hover:translate-y-0"
          >
            <svg viewBox="0 0 24 24" width="18" height="18" className="w-4.5 h-4.5" fill="currentColor">
              <path d="M12 2C6.477 2 2 6.477 2 12c0 4.42 2.867 8.167 6.839 9.49.5.092.682-.217.682-.482 0-.237-.008-.866-.013-1.7-2.782.603-3.369-1.34-3.369-1.34-.454-1.156-1.11-1.464-1.11-1.464-.908-.62.069-.608.069-.608 1.003.07 1.531 1.03 1.531 1.03.892 1.529 2.341 1.087 2.91.831.092-.646.35-1.086.636-1.336-2.22-.253-4.555-1.11-4.555-4.943 0-1.091.39-1.984 1.029-2.683-.103-.253-.446-1.27.098-2.647 0 0 .84-.269 2.75 1.025A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.294 2.747-1.025 2.747-1.025.546 1.377.203 2.394.1 2.647.64.699 1.028 1.592 1.028 2.683 0 3.842-2.339 4.687-4.566 4.935.359.309.678.919.678 1.852 0 1.336-.012 2.415-.012 2.743 0 .267.18.579.688.481C19.137 20.164 22 16.418 22 12c0-5.523-4.523-10-10-10z"/>
            </svg>
            <span>Sign In with GitHub</span>
          </button>
        </form>

        <div className="mt-8 text-center border-t border-gray-100 pt-6">
          <p className="text-sm text-gray-500 font-medium">
            New developer? <Link to="/developer/register" className="text-accent hover:text-accent-dark font-bold">Get API Key →</Link>
          </p>
        </div>
      </div>
    </div>
  );
}
