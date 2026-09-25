import React, { useState, useEffect, useRef } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { seekerAPI, publicAPI } from '../../lib/api';
import { useSeekerAuthStore } from '../../stores/seekerAuthStore';
import toast from 'react-hot-toast';
import { Eye, EyeOff, UploadCloud, Sparkles, Loader2, Check } from 'lucide-react';
import VerificationModal from '../../components/VerificationModal';
import { LocationSelector } from '../../components/ui/LocationSelector';

export default function JobSeekerRegisterPage() {
  const navigate = useNavigate();
  const setAuth = useSeekerAuthStore(s => s.setAuth);
  const [form, setForm] = useState({ full_name: '', email: '', password: '', location: '', headline: '', phone: '' });
  const [isEmailVerified, setIsEmailVerified] = useState(false);
  const [verifyTarget, setVerifyTarget] = useState(null);
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [parsingResume, setParsingResume] = useState(false);
  const googleClientRef = useRef(null);

  const handleAutoFillFromResume = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setParsingResume(true);
    const toastId = toast.loading("Extracting profile details from resume...");
    try {
      const data = await publicAPI.parseResume(file);
      setForm(prev => ({
        ...prev,
        full_name: data.full_name || prev.full_name,
        email: data.email || prev.email,
        phone: data.phone || prev.phone,
        location: data.location || prev.location,
        headline: data.headline || prev.headline,
        skills: data.skills || prev.skills || [],
        resume_file_path: data.resume_file_path || prev.resume_file_path,
        resume_data: data.raw_parsed_data || prev.resume_data,
      }));
      if (data.email) setIsEmailVerified(false);
      toast.success("Profile details auto-filled from resume!", { id: toastId });
    } catch (err) {
      toast.error(err.message || "Failed to parse resume", { id: toastId });
    } finally {
      setParsingResume(false);
    }
  };

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
                const data = await seekerAPI.googleLogin(tokenResponse.access_token);
                if (data.seeker?.requires_profile_completion) {
                  localStorage.removeItem("vish_seeker_token");
                  localStorage.removeItem("vish_seeker_data");
                  sessionStorage.setItem('temp_oauth_data', JSON.stringify({ role: 'seeker', data }));
                  navigate('/auth/complete-profile');
                  return;
                }
                setAuth(data);
                toast.success('Signed up successfully with Google!');
                navigate('/jobs/dashboard');
              } catch (err) {
                toast.error(err.message || 'Google signup failed');
              } finally {
                setLoading(false);
              }
            }
          }
        });
      }
    };
    document.body.appendChild(script);
  }, [navigate, setAuth]);

  const handle = async (e) => {
    e.preventDefault();
    if (!isEmailVerified) { toast.error('Please verify your email address first'); return; }
    if (form.password.length < 8) { toast.error('Password must be at least 8 characters'); return; }
    setLoading(true);
    try {
      const data = await seekerAPI.register(form);
      setAuth(data);
      localStorage.setItem('vish_seeker_token', data.seeker_token);
      localStorage.setItem('vish_seeker_data', JSON.stringify(data.seeker));
      toast.success('Account created! Welcome to Between!');
      navigate('/jobs/dashboard');
    } catch (err) {
      toast.error(err.message || 'Registration failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center relative bg-bg overflow-hidden font-sans py-12">
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_center,_var(--tw-gradient-stops))] from-gray-100 via-bg to-bg opacity-70"></div>
      
      <div className="w-full max-w-md bg-white rounded-3xl p-8 relative z-10 shadow-2xl shadow-gray-200/50 border border-gray-100 m-4">
        <div className="flex flex-col items-center mb-6">
          <span className="text-gray-500 text-[14px] font-medium mb-1">Job Seeker Portal</span>
          <h1 className="text-3xl font-black tracking-tight text-accent">Create Account</h1>
        </div>

        {/* Resume Upload Auto-Fill Dropzone */}
        <div className="mb-4 p-4 border-2 border-dashed border-blue-200 bg-blue-50/50 hover:bg-blue-50 hover:border-blue-400 rounded-2xl transition-colors text-center group">
          <input 
            type="file" 
            id="register-resume-upload" 
            accept=".pdf,.docx,.doc,.txt"
            className="hidden" 
            onChange={handleAutoFillFromResume}
            disabled={parsingResume}
          />
          <label htmlFor="register-resume-upload" className="cursor-pointer block space-y-1.5">
            {parsingResume ? (
              <Loader2 className="mx-auto text-blue-600 animate-spin w-6 h-6" />
            ) : (
              <UploadCloud className="mx-auto text-blue-500 group-hover:scale-110 transition-transform w-6 h-6" />
            )}
            <div className="text-xs font-bold text-blue-900 flex items-center justify-center gap-1">
              <Sparkles size={14} className="text-blue-600" />
              <span>{parsingResume ? "Parsing resume details..." : "Auto-fill registration using Resume PDF / DOCX"}</span>
            </div>
            <p className="text-[10px] text-blue-600 font-medium">Upload resume to extract Name, Email, Phone, Location & Headline automatically</p>
          </label>
        </div>

        <form onSubmit={handle} className="flex flex-col gap-4">
          <div className="flex flex-col gap-1.5">
            <label className="text-sm font-semibold text-charcoal">Full Name *</label>
            <input 
              type="text" 
              placeholder="Daksh Bhavsar" 
              value={form.full_name}
              onChange={e => setForm(p => ({ ...p, full_name: e.target.value }))}
              className="w-full px-4 py-2.5 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-accent/20 focus:border-accent outline-none transition-all placeholder:text-gray-400 font-medium"
              required 
            />
          </div>

          <div className="flex flex-col gap-1.5">
            <label className="text-sm font-semibold text-charcoal">Email Address *</label>
            <div className="flex gap-2" style={{ display: 'flex', gap: '8px' }}>
              <input 
                type="email" 
                placeholder="you@example.com" 
                value={form.email}
                disabled={isEmailVerified}
                onChange={e => {
                  setForm(p => ({ ...p, email: e.target.value }));
                  setIsEmailVerified(false);
                }}
                className="w-full px-4 py-2.5 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-accent/20 focus:border-accent outline-none transition-all placeholder:text-gray-400 font-medium"
                required 
                style={{ flex: 1 }}
              />
              {/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email) && (
                <button
                  type="button"
                  disabled={isEmailVerified}
                  onClick={() => {
                    setVerifyTarget({ type: 'email', value: form.email.trim(), role: 'seeker', isSignup: true });
                  }}
                  className={`px-4 text-xs font-bold rounded-xl transition-all ${
                    isEmailVerified 
                      ? 'bg-emerald-950/40 text-emerald-400 border border-emerald-800/50 cursor-default'
                      : 'bg-accent text-white hover:bg-accent-dark'
                  }`}
                  style={{ minWidth: '85px', height: '42px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}
                >
                  {isEmailVerified ? <span className="flex items-center gap-1">Verified <Check className="w-3.5 h-3.5 inline text-emerald-400" /></span> : 'Verify'}
                </button>
              )}
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="flex flex-col gap-1.5">
              <label className="text-sm font-semibold text-charcoal">Location (Country / State / City)</label>
              <LocationSelector
                value={form.location}
                onChange={(loc) => setForm(p => ({ ...p, location: loc }))}
                isLight={true}
              />
            </div>
            <div className="flex flex-col gap-1.5">
              <label className="text-sm font-semibold text-charcoal">Password *</label>
              <div className="relative w-full">
                <input 
                  type={showPassword ? "text" : "password"} 
                  placeholder="Min. 8 chars" 
                  value={form.password}
                  onChange={e => setForm(p => ({ ...p, password: e.target.value }))}
                  className="w-full px-4 py-2.5 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-accent/20 focus:border-accent outline-none transition-all placeholder:text-gray-400 font-medium pr-12"
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
          </div>

          <div className="flex flex-col gap-1.5">
            <label className="text-sm font-semibold text-charcoal">Headline</label>
            <input 
              type="text" 
              placeholder="e.g. Full Stack Developer · 3 years exp" 
              value={form.headline}
              onChange={e => setForm(p => ({ ...p, headline: e.target.value }))}
              className="w-full px-4 py-2.5 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-accent/20 focus:border-accent outline-none transition-all placeholder:text-gray-400 font-medium"
            />
          </div>

          <button 
            type="submit" 
            disabled={loading}
            className="w-full mt-2 bg-accent text-white py-3 rounded-xl font-bold tracking-wide hover:bg-accent-dark transition-all shadow-md shadow-accent/20 hover:-translate-y-0.5 disabled:opacity-70 disabled:hover:translate-y-0"
          >
            {loading ? "Creating account..." : "Create Account"}
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
            className="w-full flex items-center justify-center gap-2.5 bg-white border border-gray-200 text-charcoal py-3 rounded-xl font-bold tracking-wide hover:bg-gray-50 transition-all shadow-sm hover:-translate-y-0.5 disabled:opacity-70 disabled:hover:translate-y-0"
          >
            <svg viewBox="0 0 24 24" width="18" height="18" className="w-4.5 h-4.5">
              <path d="M21.35,11.1H12v2.7h5.38C17,14.93,15.76,15.9,14.15,16.5l2.2,2.2c2.6-2.4,4.1-5.9,4.1-10C22.45,12.3,22,11.6,21.35,11.1z" fill="#4285F4" />
              <path d="M12,20.45c2.6,0,4.8-.85,6.4-2.3l-2.2-2.2c-.85.6-2,1-3.3,1c-3.15,0-5.8-2.15-6.75-5.05L3.9,13.9A10.45,10.45,0,0,0,12,20.45z" fill="#34A853" />
              <path d="M5.25,12.1a6.4,6.4,0,0,1,0-3.8L3.05,6A10.45,10.45,0,0,0,3.05,16.2z" fill="#FBBC05" />
              <path d="M12,5.25c1.8,0,3.2.6,4.05,1.4l2-2A10.35,10.35,0,0,0,12,1.55a10.45,10.45,0,0,0-8.1,4.45L6.1,8.1C7.05,5.2,9.7,3.15,12,5.25z" fill="#EA4335" />
            </svg>
            <span>Sign Up with Google</span>
          </button>

          <button 
            type="button" 
            disabled={loading}
            onClick={() => {
              const clientId = import.meta.env.VITE_GITHUB_CLIENT_ID;
              const redirectUri = encodeURIComponent(window.location.origin + '/auth/github/callback');
              window.location.href = `https://github.com/login/oauth/authorize?client_id=${clientId}&redirect_uri=${redirectUri}&scope=read:user,user:email&state=seeker`;
            }}
            className="w-full flex items-center justify-center gap-2.5 bg-white border border-gray-200 text-charcoal py-3 rounded-xl font-bold tracking-wide hover:bg-gray-50 transition-all shadow-sm hover:-translate-y-0.5 disabled:opacity-70 disabled:hover:translate-y-0"
          >
            <svg viewBox="0 0 24 24" width="18" height="18" className="w-4.5 h-4.5" fill="currentColor">
              <path d="M12 2C6.477 2 2 6.477 2 12c0 4.42 2.867 8.167 6.839 9.49.5.092.682-.217.682-.482 0-.237-.008-.866-.013-1.7-2.782.603-3.369-1.34-3.369-1.34-.454-1.156-1.11-1.464-1.11-1.464-.908-.62.069-.608.069-.608 1.003.07 1.531 1.03 1.531 1.03.892 1.529 2.341 1.087 2.91.831.092-.646.35-1.086.636-1.336-2.22-.253-4.555-1.11-4.555-4.943 0-1.091.39-1.984 1.029-2.683-.103-.253-.446-1.27.098-2.647 0 0 .84-.269 2.75 1.025A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.294 2.747-1.025 2.747-1.025.546 1.377.203 2.394.1 2.647.64.699 1.028 1.592 1.028 2.683 0 3.842-2.339 4.687-4.566 4.935.359.309.678.919.678 1.852 0 1.336-.012 2.415-.012 2.743 0 .267.18.579.688.481C19.137 20.164 22 16.418 22 12c0-5.523-4.523-10-10-10z"/>
            </svg>
            <span>Sign Up with GitHub</span>
          </button>
        </form>

        <div className="mt-8 text-center border-t border-gray-100 pt-6 flex flex-col gap-2">
          <p className="text-sm text-gray-500 font-medium">
            Already have an account? <Link to="/jobs/login" className="text-accent hover:text-accent-dark font-bold">Sign In</Link>
          </p>
          <p className="text-xs text-gray-400 font-medium">
            Are you a company? <Link to="/register" className="text-[#6366f1] hover:text-[#4f46e5] font-bold">Company Register →</Link>
          </p>
        </div>
      </div>
      {verifyTarget && (
        <VerificationModal
          isOpen={true}
          onClose={() => setVerifyTarget(null)}
          type={verifyTarget.type}
          value={verifyTarget.value}
          role={verifyTarget.role}
          isSignup={verifyTarget.isSignup}
          userEmail={form.email}
          onSuccess={() => {
            if (verifyTarget.type === 'email') {
              setIsEmailVerified(true);
            }
          }}
        />
      )}
    </div>
  );
}
