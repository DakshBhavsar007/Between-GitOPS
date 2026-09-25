import React, { useState, useEffect, useRef } from "react";
import { useNavigate, Link } from "react-router-dom";
import { toast } from "react-hot-toast";
import { motion } from "framer-motion";
import { Check, Copy, Eye, EyeOff, AlertTriangle } from "lucide-react";
import { portalAuth, portalBilling } from "../../lib/portalApi";
import { usePortalAuthStore } from "../../stores/portalAuthStore";
import VerificationModal from "../../components/VerificationModal";
import { DEVELOPER_PLANS } from "../../lib/plans";

export default function DeveloperRegisterPage() {
  const [step, setStep] = useState(1);
  const navigate = useNavigate();
  const { setAuth } = usePortalAuthStore();
  const googleClientRef = useRef(null);

  // Form State
  const [form, setForm] = useState({ company_name: "", email: "", password: "", website_url: "" });
  const [plans, setPlans] = useState([]);
  const [selectedPlan, setSelectedPlan] = useState("starter");
  const [loading, setLoading] = useState(false);
  const [apiKeysData, setApiKeysData] = useState(null);
  const [isEmailVerified, setIsEmailVerified] = useState(false);
  const [verifyTarget, setVerifyTarget] = useState(null);

  // UI state
  const [showTestSecret, setShowTestSecret] = useState(false);
  const [showLiveSecret, setShowLiveSecret] = useState(false);
  const [keysSaved, setKeysSaved] = useState(false);
  const [showPassword, setShowPassword] = useState(false);

  useEffect(() => {
    // Dynamically load Razorpay
    const script = document.createElement("script");
    script.src = "https://checkout.razorpay.com/v1/checkout.js";
    script.async = true;
    document.body.appendChild(script);

    // Dynamically load Google client
    const googleScript = document.createElement("script");
    googleScript.src = "https://accounts.google.com/gsi/client";
    googleScript.async = true;
    googleScript.defer = true;
    googleScript.onload = () => {
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
                if (data.is_new) {
                  setApiKeysData(data);
                  toast.success("Account created successfully with Google!");
                  setStep(3);
                } else {
                  setAuth(data);
                  if (typeof window !== "undefined") {
                    localStorage.setItem("portal_jwt", data.jwt_token);
                    localStorage.setItem("portal_dev", JSON.stringify(data));
                  }
                  toast.success("Welcome back! Signed in with Google.");
                  navigate("/developer/portal/dashboard");
                }
              } catch (err) {
                toast.error(err.message || "Google registration failed");
              } finally {
                setLoading(false);
              }
            }
          }
        });
      }
    };
    document.body.appendChild(googleScript);

    portalBilling.plans()
      .then(d => { if (d && d.length > 0) setPlans(d); })
      .catch(e => {
        setPlans(DEVELOPER_PLANS);
      });

    return () => {
      document.body.removeChild(script);
      try {
        document.body.removeChild(googleScript);
      } catch (err) {
        // Safe check
      }
    };
  }, [navigate, setAuth]);

  const handleStep1 = (e) => {
    e.preventDefault();
    if (!form.company_name || !form.email || !form.password) {
      return toast.error("Please fill all required fields");
    }
    if (!isEmailVerified) {
      return toast.error("Please verify your email address first");
    }
    setStep(2);
  };

  const proceedWithRegistration = async () => {
    setLoading(true);
    try {
      const data = await portalAuth.register({...form, tier: selectedPlan});
      setApiKeysData(data); // Expecting keys and credentials
      setStep(3);
    } catch (e) {
      toast.error(e.message || "Registration failed");
    } finally {
      setLoading(false);
    }
  };

  const handleSelectPlan = async () => {
    const planDetails = plans.find(p => p.id === selectedPlan);
    if (!planDetails) return;

    // Temporarily bypass Razorpay integration. 
    // Directly proceed to registration with the selected tier limits.
    await proceedWithRegistration();
  };

  const copyToClipboard = (text) => {
    navigator.clipboard.writeText(text);
    toast.success("Copied to clipboard!");
  };

  const copyAllKeys = () => {
    const text = `Between API Keys\n\nTest Public: ${apiKeysData?.test_public_key || '...'}\nTest Secret: ${apiKeysData?.test_secret_key || '...'}\n\nLive Public: ${apiKeysData?.public_key || '...'}\nLive Secret: ${apiKeysData?.secret_key || '...'}`;
    copyToClipboard(text);
  };

  const finishSetup = () => {
    if (!keysSaved) return toast.error("Please confirm you have saved the keys");
    setAuth(apiKeysData);
    if (typeof window !== "undefined" && apiKeysData?.jwt_token) {
      localStorage.setItem("portal_jwt", apiKeysData.jwt_token);
      localStorage.setItem("portal_dev", JSON.stringify(apiKeysData));
    }
    navigate("/developer/portal/dashboard");
  };

  return (
    <div className="min-h-screen bg-bg flex items-center justify-center font-sans p-6 pb-20 pt-10">
      
      {/* STEP 1 */}
      {step === 1 && (
        <motion.div initial={{opacity:0, y:20}} animate={{opacity:1, y:0}} className="w-full max-w-md bg-white rounded-3xl p-8 shadow-2xl shadow-gray-200/50 border border-gray-100">
          <div className="mb-8 text-center">
             <h1 className="text-3xl font-black text-charcoal mb-2">Get your API Key</h1>
             <p className="text-gray-500 font-medium tracking-tight">Start integrating Between in minutes</p>
          </div>
          <form onSubmit={handleStep1} className="flex flex-col gap-4">
             <div className="flex flex-col gap-1.5">
                <label className="text-sm font-semibold text-charcoal">Company Name*</label>
                <input autoFocus type="text" value={form.company_name} onChange={e=>setForm({...form, company_name:e.target.value})} className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-accent/20 focus:border-accent outline-none font-medium" required />
             </div>
             <div className="flex flex-col gap-1.5">
                <label className="text-sm font-semibold text-charcoal">Work Email*</label>
                <div className="flex gap-2" style={{ display: 'flex', gap: '8px' }}>
                  <input 
                    type="email" 
                    value={form.email} 
                    disabled={isEmailVerified}
                    onChange={e => {
                      setForm({...form, email:e.target.value});
                      setIsEmailVerified(false);
                    }} 
                    className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-accent/20 focus:border-accent outline-none font-medium" 
                    required 
                    style={{ flex: 1 }}
                  />
                  {/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email) && (
                    <button
                      type="button"
                      disabled={isEmailVerified}
                      onClick={() => {
                        setVerifyTarget({ type: 'email', value: form.email.trim(), role: 'developer', isSignup: true });
                      }}
                      className={`px-4 text-xs font-bold rounded-xl transition-all ${
                        isEmailVerified 
                          ? 'bg-emerald-950/40 text-emerald-400 border border-emerald-800/50 cursor-default'
                          : 'bg-accent text-white hover:bg-accent-dark'
                      }`}
                      style={{ minWidth: '85px', height: '48px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}
                    >
                      {isEmailVerified ? <span className="flex items-center gap-1">Verified <Check className="w-3.5 h-3.5 inline text-emerald-400" /></span> : 'Verify'}
                    </button>
                  )}
                </div>
             </div>
             <div className="flex flex-col gap-1.5">
                <label className="text-sm font-semibold text-charcoal">Password*</label>
                <div className="relative w-full">
                  <input 
                    type={showPassword ? "text" : "password"} 
                    value={form.password} 
                    onChange={e=>setForm({...form, password:e.target.value})} 
                    className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-accent/20 focus:border-accent outline-none font-medium pr-12" 
                    required 
                    minLength={8}
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-accent transition-colors"
                  >
                    {showPassword ? <EyeOff size={20} /> : <Eye size={20} />}
                  </button>
                </div>
                <div className="flex gap-1 mt-1">
                  <div className={`h-1 w-1/3 rounded-full ${form.password.length > 0 ? "bg-red-400" : "bg-gray-200"}`}></div>
                  <div className={`h-1 w-1/3 rounded-full ${form.password.length > 5 ? "bg-amber-400" : "bg-gray-200"}`}></div>
                  <div className={`h-1 w-1/3 rounded-full ${form.password.length > 8 ? "bg-green-400" : "bg-gray-200"}`}></div>
                </div>
             </div>
             <div className="flex flex-col gap-1.5">
                <label className="text-sm font-semibold text-charcoal">Website URL (optional)</label>
                <input type="url" placeholder="https://" value={form.website_url} onChange={e=>setForm({...form, website_url:e.target.value})} className="w-full px-4 py-3 bg-gray-50 border border-gray-200 rounded-xl focus:ring-2 focus:ring-accent/20 focus:border-accent outline-none font-medium" />
             </div>
             <button type="submit" className="w-full mt-4 bg-accent text-white py-3.5 rounded-xl font-bold hover:bg-accent-dark transition-all shadow-md shadow-accent/20">
                Continue &rarr;
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
               <span>Sign Up with Google</span>
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
               <span>Sign Up with GitHub</span>
             </button>

             <p className="text-center text-sm font-medium text-gray-500 mt-4">Already have an account? <Link to="/developer/login" className="text-accent hover:underline">Sign In</Link></p>
          </form>
        </motion.div>
      )}

      {/* STEP 2 */}
      {step === 2 && (
        <motion.div initial={{opacity:0, scale:0.95}} animate={{opacity:1, scale:1}} className="w-full max-w-5xl">
           <div className="text-center mb-12">
             <h1 className="text-3xl lg:text-4xl font-black text-charcoal mb-3">Choose your plan</h1>
             <p className="text-gray-500 font-medium">Select a tier that fits your usage.</p>
           </div>
           <div className="grid md:grid-cols-3 gap-6">
             {plans.map(p => (
               <div key={p.id} onClick={() => setSelectedPlan(p.id)} className={`cursor-pointer border-2 rounded-3xl p-6 bg-white transition-all ${selectedPlan === p.id ? "border-accent shadow-xl shadow-amber-500/10 scale-105" : "border-gray-100 hover:border-gray-300"}`}>
                 <div className="flex justify-between items-center mb-4">
                   <h3 className="text-xl font-bold uppercase">{p.name}</h3>
                   {p.id === "starter" && <span className="bg-blue-100 text-amber-800 text-[10px] font-black uppercase px-2 py-1 rounded-full">Popular</span>}
                   {selectedPlan === p.id && <Check className="text-accent" />}
                 </div>
                 <div className="mb-6 border-b border-gray-100 pb-6">
                   <span className="text-4xl font-black">₹{p.price}</span>
                   <span className="text-gray-500 font-medium text-sm">/month</span>
                 </div>
                 <ul className="flex flex-col gap-3 font-medium text-sm text-gray-600 mb-8 min-h-[160px]">
                   {p.features.map(f => (
                     <li key={f} className="flex gap-2 items-start"><Check size={16} className="text-green-500 shrink-0 mt-0.5" /> <span>{f}</span></li>
                   ))}
                 </ul>
                 <button className={`w-full py-3 rounded-xl font-bold ${selectedPlan === p.id ? "bg-accent text-white" : "bg-gray-100 text-charcoal"}`}>
                   {selectedPlan === p.id ? <span className="flex items-center justify-center gap-1">Selected <Check className="w-4 h-4 inline" /></span> : "Select Plan"}
                 </button>
               </div>
             ))}
           </div>
           <div className="mt-12 flex justify-center sticky bottom-4">
              <button disabled={loading} onClick={handleSelectPlan} className="bg-charcoal text-white px-10 py-4 rounded-full font-bold shadow-2xl hover:bg-black transition-all flex items-center gap-3 disabled:opacity-50">
                {loading ? "Processing..." : `Pay \u20B9${plans.find(p=>p.id===selectedPlan)?.price || '0'} & Register →`}
              </button>
           </div>
           <p className="text-center mt-4 text-sm font-medium text-gray-500">
             <button onClick={()=>setStep(1)} className="hover:text-charcoal hover:underline">← Back to Details</button>
           </p>
        </motion.div>
      )}

      {/* STEP 3 */}
      {step === 3 && (
        <motion.div initial={{opacity:0, scale:0.9}} animate={{opacity:1, scale:1}} className="w-full max-w-4xl bg-white rounded-3xl p-10 shadow-2xl shadow-gray-200/50">
           <div className="flex flex-col items-center mb-8">
              <motion.div initial={{scale:0}} animate={{scale:1}} className="w-20 h-20 bg-green-100 rounded-full flex items-center justify-center text-green-600 mb-6">
                <Check size={40} className="stroke-[3]" />
              </motion.div>
              <h1 className="text-4xl font-black text-charcoal ">Welcome to Between!</h1>
            </div>

           <div className="bg-red-50 border-2 border-red-200 rounded-xl p-4 mb-8 flex items-start gap-3">
             <AlertTriangle className="text-red-500 shrink-0 mt-0.5" />
             <div>
               <h4 className="font-bold text-red-800">Copy your secret keys NOW.</h4>
               <p className="text-sm font-medium text-red-600 mt-1">For security reasons, they will <strong className="font-black">NEVER</strong> be shown again. If you lose them, you will have to generate new keys.</p>
             </div>
           </div>

           <div className="grid md:grid-cols-2 gap-6 mb-8">
             {/* TEST KEYS */}
             <div className="border border-gray-200 rounded-2xl p-6 bg-gray-50 relative overflow-hidden">
                <div className="absolute top-0 left-0 w-full h-1 bg-gray-400"></div>
                <h3 className="font-bold text-gray-700 mb-4 flex items-center gap-2">Test Keys <span className="text-xs bg-gray-200 px-2 py-0.5 rounded-full font-semibold">Development</span></h3>
                
                <div className="flex flex-col gap-3">
                  <div>
                    <span className="text-xs font-bold text-gray-400 uppercase tracking-widest pl-1">Public Key</span>
                    <div className="flex items-center gap-2 mt-1 bg-white border border-gray-200 rounded-lg p-2 px-3">
                      <code className="text-sm flex-1 text-gray-600 font-mono truncate">{apiKeysData?.test_public_key || "vish_pub_test_..."}</code>
                      <button onClick={()=>copyToClipboard(apiKeysData?.test_public_key)} className="text-gray-400 hover:text-charcoal"><Copy size={16}/></button>
                    </div>
                  </div>
                  <div>
                    <span className="text-xs font-bold text-gray-400 uppercase tracking-widest pl-1">Secret Key</span>
                    <div className="flex items-center gap-2 mt-1 bg-white border border-gray-200 rounded-lg p-2 px-3">
                      <code className="text-sm flex-1 text-gray-600 font-mono truncate">
                        {showTestSecret ? (apiKeysData?.test_secret_key || "vish_test_...") : "••••••••••••••••••••••••"}
                      </code>
                      <button onClick={()=>setShowTestSecret(!showTestSecret)} className="text-gray-400 hover:text-charcoal mr-1">{showTestSecret ? <EyeOff size={16}/> : <Eye size={16}/>}</button>
                      <button onClick={()=>copyToClipboard(apiKeysData?.test_secret_key)} className="text-gray-400 hover:text-charcoal"><Copy size={16}/></button>
                    </div>
                  </div>
                </div>
             </div>

             {/* LIVE KEYS */}
             <div className="border-2 border-accent rounded-2xl p-6 bg-[#fffcf5] relative overflow-hidden shadow-lg shadow-amber-500/5">
                <div className="absolute top-0 left-0 w-full h-1 bg-accent"></div>
                <h3 className="font-bold text-accent-dark mb-4 flex items-center gap-2">Live Keys <span className="text-xs bg-accent/20 text-accent px-2 py-0.5 rounded-full font-semibold">Production</span></h3>
                
                <div className="flex flex-col gap-3">
                  <div>
                    <span className="text-xs font-bold text-accent uppercase tracking-widest pl-1">Public Key</span>
                    <div className="flex items-center gap-2 mt-1 bg-white border border-accent/20 rounded-lg p-2 px-3">
                      <code className="text-sm flex-1 text-gray-700 font-mono truncate">{apiKeysData?.public_key || apiKeysData?.api_key || "vish_pub_..."}</code>
                      <button onClick={()=>copyToClipboard(apiKeysData?.public_key || apiKeysData?.api_key)} className="text-gray-400 hover:text-charcoal"><Copy size={16}/></button>
                    </div>
                  </div>
                  <div>
                    <span className="text-xs font-bold text-red-500 uppercase tracking-widest pl-1">Secret Key</span>
                    <div className="flex items-center gap-2 mt-1 bg-white border border-red-200 rounded-lg p-2 px-3">
                      <code className="text-sm flex-1 text-red-600 font-mono truncate font-bold">
                        {showLiveSecret ? (apiKeysData?.secret_key) : "••••••••••••••••••••••••"}
                      </code>
                      <button onClick={()=>setShowLiveSecret(!showLiveSecret)} className="text-gray-400 hover:text-charcoal mr-1">{showLiveSecret ? <EyeOff size={16}/> : <Eye size={16}/>}</button>
                      <button onClick={()=>copyToClipboard(apiKeysData?.secret_key)} className="text-gray-400 hover:text-charcoal"><Copy size={16}/></button>
                    </div>
                  </div>
                </div>
             </div>
           </div>

           <div className="flex flex-col items-center border-t border-gray-100 pt-8 mt-4 gap-6">
              <button onClick={copyAllKeys} className="px-6 py-2.5 rounded-xl border-2 border-charcoal font-bold text-charcoal hover:bg-gray-100 transition-colors flex gap-2 items-center">
                <Copy size={18} /> Copy All Keys
              </button>

              <label className="flex items-center gap-3 cursor-pointer bg-gray-50 border border-gray-200 px-5 py-3 rounded-xl select-none w-full justify-center max-w-lg">
                <input type="checkbox" checked={keysSaved} onChange={e=>setKeysSaved(e.target.checked)} className="w-5 h-5 accent-accent" />
                <span className="font-semibold text-charcoal flex items-center gap-1.5"><Check className="w-4 h-4 text-emerald-600 inline" /> I have securely saved all my API keys</span>
              </label>

              <button 
                onClick={finishSetup} 
                disabled={!keysSaved}
                className="w-full max-w-lg bg-accent text-white py-4 rounded-2xl font-bold tracking-wide hover:bg-accent-dark transition-all shadow-md shadow-accent/20 disabled:opacity-50 disabled:grayscale"
              >
                Go to Developer Dashboard &rarr;
              </button>
           </div>
        </motion.div>
      )}
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
