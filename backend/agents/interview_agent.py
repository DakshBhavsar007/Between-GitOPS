"""
AI Interview conductor using Groq API for low-latency real-time responses.
Generates questions from resume + job context.
Evaluates each answer in real-time.
Produces final interview summary.
DOES NOT touch any existing agent.
"""
import json
import os
import logging
from openai import OpenAI
from agents.llm import RotateLLMClient

logger = logging.getLogger(__name__)

# Initialize Groq client if key exists, otherwise we will fallback to RotateLLMClient
groq_key = os.environ.get("GROQ_API_KEY")
if groq_key:
    try:
        GROQ_CLIENT = OpenAI(
            api_key=groq_key,
            base_url="https://api.groq.com/openai/v1"
        )
    except Exception as e:
        logger.warning(f"Failed to initialize GROQ_CLIENT: {e}")
        GROQ_CLIENT = None
else:
    GROQ_CLIENT = None

GROQ_MODEL = os.environ.get("GROQ_INTERVIEW_MODEL", "llama-3.3-70b-versatile")


class InterviewAgent:
    def __init__(self):
        self.fallback_client = RotateLLMClient(agent_name="interview_agent")

    def _call_llm(self, prompt: str, json_mode: bool = True) -> str:
        """Helper to call Groq (if available) or fallback to RotateLLMClient"""
        if GROQ_CLIENT:
            try:
                response = GROQ_CLIENT.chat.completions.create(
                    model=GROQ_MODEL,
                    messages=[{"role": "user", "content": prompt}],
                    temperature=0.2,
                    response_format={"type": "json_object"} if json_mode else None,
                    timeout=20
                )
                return response.choices[0].message.content
            except Exception as e:
                logger.error("Groq call failed, falling back to RotateLLMClient: %s", e)

        # Fallback using RotateLLMClient
        try:
            response = self.fallback_client.chat.completions.create(
                model="gemini-2.5-flash",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.2,
                response_format={"type": "json_object"} if json_mode else None,
                timeout=20
            )
            return response.choices[0].message.content
        except Exception as e:
            logger.error("Fallback LLM call failed: %s", e)
            if json_mode:
                return "{}"
            return ""

    def generate_questions(
        self,
        job_title: str,
        job_description: str,
        candidate_resume: dict,
        manual_questions: list,
        total_questions: int = 5,
        interview_mode: str = "technical"
    ) -> list:
        """
        Merges company's manual questions with AI-generated resume-aware questions.
        Supports interview_mode: 'technical', 'hr', or 'screening'.
        """
        manual_count = len(manual_questions)
        ai_needed = max(0, total_questions - manual_count)

        ai_questions = []
        if ai_needed > 0:
            parsed_resume = candidate_resume.get('parsed', {}) if 'parsed' in candidate_resume else candidate_resume
            projects = [p.get('name', '') for p in parsed_resume.get('projects', []) if p.get('name')]
            skills = parsed_resume.get('skills', [])[:15]
            skills_list = []
            for s in skills:
                if isinstance(s, dict):
                    skills_list.append(s.get('skill', ''))
                else:
                    skills_list.append(str(s))
            skills_list = [s for s in skills_list if s]

            experience = [
                f"{e.get('title','')} at {e.get('company','')}"
                for e in parsed_resume.get('experience', []) if e.get('title')
            ]

            mode_lower = (interview_mode or "technical").lower()
            if "hr" in mode_lower or "behavioral" in mode_lower:
                role_prompt = "You are an experienced HR Manager and Behavioral Interviewer conducting a professional HR Round."
                guidelines = """Rules:
1. Ask realistic HR & behavioral questions (situational judgment, teamwork, handling pressure/tight deadlines).
2. Ask about notice period, CTC expectations, career goals, and work culture fit.
3. Keep tone supportive, encouraging yet evaluating."""
            elif "screening" in mode_lower:
                role_prompt = "You are a Talent Acquisition Specialist conducting an initial screening interview."
                guidelines = """Rules:
1. Ask questions validating key claims on candidate's resume and project experience.
2. Verify candidate motivation and basic eligibility for the role."""
            else:
                role_prompt = "You are a Senior Technical Lead conducting a deep technical interview."
                guidelines = """Rules:
1. Make questions SPECIFIC to technical architecture, coding paradigms, and listed skills.
2. Vary difficulty: 1 easy warmup, rest medium-hard."""

            prompt = f"""
{role_prompt}
Generate exactly {ai_needed} interview questions for this candidate.

Job Title: {job_title}
Job Requirements: {job_description[:400]}

Candidate Profile:
- Skills: {skills_list}
- Projects: {projects}
- Experience: {experience}

Already planned questions (do NOT repeat these topics):
{json.dumps(manual_questions)}

{guidelines}

Return ONLY valid JSON (no markdown block):
{{
  "questions": [
    {{
      "q": "Question here...",
      "type": "project_deep_dive/technical/behavioral",
      "source": "resume",
      "expected_keywords": ["keyword1", "keyword2"]
    }}
  ]
}}
"""
            try:
                res_content = self._call_llm(prompt, json_mode=True)
                ai_questions = json.loads(res_content).get("questions", [])
            except Exception as e:
                logger.error("Parsing questions JSON failed: %s", e)
                ai_questions = []

            # If failed or returned fewer than needed, add fallbacks
            while len(ai_questions) < ai_needed:
                ai_questions.append({
                    "q": "Walk me through your most complex project and the biggest technical challenge you faced.",
                    "type": "project_general",
                    "source": "fallback",
                    "expected_keywords": []
                })

        manual_formatted = [
            {
                "q": q,
                "type": "manual",
                "source": "company",
                "expected_keywords": []
            }
            for q in manual_questions
        ]

        return (manual_formatted + ai_questions)[:total_questions]

    def evaluate_answer(
        self,
        question: str,
        expected_keywords: list,
        answer_text: str,
        job_title: str
    ) -> dict:
        """
        Evaluates a single interview answer.
        Called in real-time after each answer is transcribed.
        Returns structured scores for storage in interview_transcript.
        """
        if not answer_text or len(answer_text.strip()) < 10:
            return {
                "relevance_score": 0,
                "depth_score": 0,
                "accuracy_score": 0.0,
                "keywords_hit": [],
                "keywords_missed": expected_keywords,
                "feedback": "No answer provided or answer is too short.",
                "sample_good_answer": ""
            }

        # Deterministic keyword check
        answer_lower = answer_text.lower()
        keywords_hit = [k for k in expected_keywords if k.lower() in answer_lower]
        keywords_missed = [k for k in expected_keywords if k.lower() not in answer_lower]

        prompt = f"""
You are a senior technical interviewer conducting a live conversational job interview for a {job_title} position.

You just asked this question:
"{question}"

The candidate responded with this answer (transcribed from voice):
"{answer_text}"

Evaluate their response across these dimensions:
1. Technical Accuracy & Knowledge (0.0 to 1.0)
2. Confidence (0 to 10) - Assess their directness, lack of unnecessary filler words, and assertive phrasing.
3. Way of Representation & Communication (0 to 10) - Structure, clarity, and articulation.
4. Relevance to the question (0 to 10).

Write a conversational, friendly, and brief response (max 2 sentences) acknowledging their answer (like a human interviewer would).
CRITICAL RULE: DO NOT ask any follow-up questions or introduce any new topics, as the next question is already pre-defined and will be asked separately. End with a simple transition phrase like "Let's move on." or "Thank you for sharing that."
For example: "Excellent explanation of how databases use indices! You correctly identified that it speeds up retrieval, although you could also mention B-tree structures."

Return ONLY a valid JSON object (no markdown block):
{{
  "relevance_score": 8,
  "depth_score": 8,
  "confidence_score": 7,
  "accuracy_score": 0.8,
  "feedback": "Conversational response goes here...",
  "sample_good_answer": "A strong answer would mention X, Y, Z with specific metrics."
}}
"""
        try:
            res_content = self._call_llm(prompt, json_mode=True)
            result = json.loads(res_content)
            result["keywords_hit"] = keywords_hit
            result["keywords_missed"] = keywords_missed
            return result
        except Exception as e:
            logger.error("Evaluate answer parsing failed: %s", e)
            keyword_score = len(keywords_hit) / max(len(expected_keywords), 1)
            return {
                "relevance_score": 5,
                "depth_score": 5,
                "accuracy_score": round(keyword_score, 2),
                "keywords_hit": keywords_hit,
                "keywords_missed": keywords_missed,
                "feedback": "Evaluation unavailable — keyword match used as fallback.",
                "sample_good_answer": ""
            }

    def generate_interview_summary(
        self,
        transcript: list,
        job_title: str,
        candidate_name: str
    ) -> dict:
        """
        Called after all questions are answered.
        Produces overall performance summary for admin results page.
        """
        if not transcript:
            return {
                "overall_score": 0,
                "strengths": [],
                "weaknesses": ["No answers recorded"],
                "recommendation": "Reject",
                "detailed_summary": "Candidate did not complete the interview.",
                "hiring_likelihood": "low"
            }

        transcript_text = "\n\n".join([
            f"Q{i+1}: {item.get('q')}\n"
            f"Answer: {item.get('answer_text', '[No answer]')}\n"
            f"Score: {item.get('accuracy_score', 0):.0%} | "
            f"Keywords hit: {item.get('keywords_hit', [])}"
            for i, item in enumerate(transcript)
        ])

        avg_score = sum(
            item.get('accuracy_score', 0) for item in transcript
        ) / len(transcript)

        prompt = f"""
You are a senior hiring manager reviewing a completed interview for {job_title}.
Candidate: {candidate_name}
Average score across {len(transcript)} questions: {avg_score:.0%}

Full Interview Transcript:
{transcript_text}

Write a fair, detailed performance review.

Return ONLY valid JSON (no markdown block):
{{
  "overall_score": 72,
  "strengths": [
    "Strong practical knowledge",
    "Clear articulation of project-specific technical decisions"
  ],
  "weaknesses": [
    "Could improve system design explanation"
  ],
  "recommendation": "Proceed to next round",
  "detailed_summary": "Candidate demonstrated strong practical experience...",
  "hiring_likelihood": "medium"
}}
"""
        try:
            res_content = self._call_llm(prompt, json_mode=True)
            return json.loads(res_content)
        except Exception as e:
            logger.error("Generate interview summary parsing failed: %s", e)
            return {
                "overall_score": int(avg_score * 100),
                "strengths": [],
                "weaknesses": [],
                "recommendation": "Proceed" if avg_score > 0.6 else "Reject",
                "detailed_summary": f"Completed interview with average score of {avg_score:.0%}.",
                "hiring_likelihood": "medium"
            }
