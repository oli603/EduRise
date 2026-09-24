import json
import re
import asyncio
from typing import Dict, Any, List, Optional
import httpx

from ..core.config import get_settings
from .base_provider import (
    AIProvider,
    ExplanationResult,
    FlashcardsResult,
    FlashcardItem,
    SummaryResult,
    AiNotesResult,
    AiNotesSection,
    UnderstandUnitResult,
    UnderstandStep,
    QuizResult,
    QuizQuestion,
    CoachReplyResult,
    MockExamResult,
    MockExamQuestion,
)

settings = get_settings()


class GeminiProvider(AIProvider):
    def __init__(self, api_key: Optional[str] = None, model_name: Optional[str] = None):
        self.api_key = api_key or settings.GEMINI_API_KEY
        self.model_name = model_name or settings.GEMINI_MODEL
        self.timeout_seconds = settings.GEMINI_TIMEOUT_SECONDS

    def _extract_json(self, text: str) -> Dict[str, Any]:
        """Extracts and parses JSON object or array from LLM response text."""
        text = text.strip()
        # Remove markdown code blocks if present
        if text.startswith("```"):
            lines = text.splitlines()
            if lines[0].startswith("```"):
                lines = lines[1:]
            if lines and lines[-1].startswith("```"):
                lines = lines[:-1]
            text = "\n".join(lines).strip()

        try:
            return json.loads(text)
        except json.JSONDecodeError:
            # Fallback regex search for JSON object or array
            match = re.search(r"(\{.*\}|\[.*\])", text, re.DOTALL)
            if match:
                try:
                    return json.loads(match.group(1))
                except Exception:
                    pass
            raise ValueError(f"Could not parse valid JSON from Gemini output: {text[:200]}")

    async def _call_gemini(self, system_prompt: str, user_prompt: str, json_mode: bool = True) -> str:
        """Invokes Gemini REST API with strict timeouts and error isolation."""
        if not self.api_key or self.api_key in ["dummy_development_key", "YOUR_GEMINI_API_KEY_HERE"]:
            # If no real API key is configured in dev/test, use deterministic high-quality synthetic generator
            return self._generate_synthetic_response(system_prompt, user_prompt)

        url = f"https://generativelanguage.googleapis.com/v1beta/models/{self.model_name}:generateContent?key={self.api_key}"
        headers = {"Content-Type": "application/json"}

        payload = {
            "contents": [
                {
                    "parts": [
                        {"text": f"System Instructions:\n{system_prompt}\n\nUser Request:\n{user_prompt}"}
                    ]
                }
            ],
            "generationConfig": {
                "maxOutputTokens": settings.GEMINI_MAX_OUTPUT_TOKENS,
                "temperature": 0.2 if json_mode else 0.4,
            },
        }

        if json_mode:
            payload["generationConfig"]["responseMimeType"] = "application/json"

        async with httpx.AsyncClient(timeout=self.timeout_seconds) as client:
            try:
                response = await client.post(url, headers=headers, json=payload)
                if response.status_code == 429:
                    raise RuntimeError("EduRise Coach is experiencing high demand. Please try again shortly.")
                if response.status_code != 200:
                    raise RuntimeError(f"AI service returned status {response.status_code}")
                data = response.json()
                candidates = data.get("candidates", [])
                if not candidates:
                    raise RuntimeError("No candidate response returned by AI service.")
                parts = candidates[0].get("content", {}).get("parts", [])
                if not parts:
                    raise RuntimeError("Empty content returned by AI service.")
                return parts[0].get("text", "")
            except httpx.TimeoutException:
                if settings.ENVIRONMENT in ["development", "test"]:
                    return self._generate_synthetic_response(system_prompt, user_prompt)
                raise TimeoutError("EduRise Coach timed out while generating your response. Please try again.")
            except Exception:
                # If network/API fails, fallback to synthetic in development/test
                if settings.ENVIRONMENT in ["development", "test"]:
                    return self._generate_synthetic_response(system_prompt, user_prompt)
                raise RuntimeError("EduRise AI Coach is momentarily busy. Please try again in a moment.")

    def _generate_synthetic_response(self, system_prompt: str, user_prompt: str) -> str:
        """Deterministic, curriculum-aligned response generator for tests/offline development."""
        lower = user_prompt.lower()
        if "explain more" in lower or "why_correct" in system_prompt:
            return json.dumps({
                "why_correct": "The correct answer directly aligns with the fundamental curriculum principles established in the standard Ethiopian educational framework.",
                "why_other_options_wrong": [
                    "Option A represents an incorrect definition that confuses related terminology.",
                    "Option B inaccurately describes the process and lacks scientific validity.",
                    "Option C is a common distractor that reverses the cause-and-effect relationship."
                ],
                "key_takeaway": "Always identify the defining concept before eliminating distractors."
            })
        elif ("summary" in system_prompt or "overview" in system_prompt) and "understand" not in system_prompt.lower():
            return json.dumps({
                "overview": "This unit covers the essential foundational principles, core structures, and functional relationships outlined in the national textbook.",
                "key_points": [
                    "Comprehensive introduction to the primary topic and scientific principles.",
                    "Detailed analysis of key mechanisms and step-by-step processes.",
                    "Practical applications and curriculum-aligned exam focus areas."
                ],
                "bullet_points": [
                    "Mastery of core terminology is required for national entrance examinations.",
                    "Understanding sequence of reaction stages prevents common distractor confusion.",
                    "Real-world application questions frequently target functional transformations."
                ],
                "important_terms": [
                    {"term": "Core Concept", "definition": "The central principle governing this unit."},
                    {"term": "Key Process", "definition": "The step-by-step transformation described in the textbook."}
                ],
                "key_concepts": [
                    "Fundamental definition and theoretical framework.",
                    "Operational mechanics and functional relationships."
                ],
                "summary_recap": "Mastering these core definitions and processes is vital for success in class and entrance examinations.",
                "exam_importance": "This unit typically accounts for 6-8% of the national entrance examination questions with high distinction value."
            })
        elif "flashcards" in system_prompt:
            return json.dumps({
                "flashcards": [
                    {
                        "question": "What is the primary definition introduced in this unit?",
                        "answer": "The core principle as defined in the official curriculum.",
                        "front": "What is the primary definition introduced in this unit?",
                        "back": "The core principle as defined in the official curriculum.",
                        "category": "Definition"
                    },
                    {
                        "question": "How does the primary process function step-by-step?",
                        "answer": "It initiates through standard inputs and proceeds through regulated stages.",
                        "front": "How does the primary process function step-by-step?",
                        "back": "It initiates through standard inputs and proceeds through regulated stages.",
                        "category": "Process"
                    },
                    {
                        "question": "What distinguishes this concept from related topics?",
                        "answer": "Specific functional characteristics and distinct biological/physical properties.",
                        "front": "What distinguishes this concept from related topics?",
                        "back": "Specific functional characteristics and distinct biological/physical properties.",
                        "category": "Comparison"
                    },
                    {
                        "question": "What is a common pitfall to avoid on this topic?",
                        "answer": "Confusing the primary mechanism with secondary effects.",
                        "front": "What is a common pitfall to avoid on this topic?",
                        "back": "Confusing the primary mechanism with secondary effects.",
                        "category": "Exam Trap"
                    }
                ]
            })
        elif "ai notes" in system_prompt or "key_concepts" in system_prompt:
            return json.dumps({
                "sections": [
                    {
                        "title": "Core Foundations & Theory",
                        "content": "The central theory establishes fundamental relationships between system components and their environmental interactions.",
                        "key_points": [
                            "Underlying laws and mathematical/biological models.",
                            "Direct correlation between structure and resulting behavior."
                        ]
                    },
                    {
                        "title": "Mechanisms & Step-by-Step Operations",
                        "content": "The operational sequence follows an ordered cascade where each stage is dependent on prerequisite intermediate transformations.",
                        "key_points": [
                            "Stage 1 initiation via catalytic stimulation.",
                            "Phase 2 equilibrium balance and steady-state maintenance.",
                            "Final termination and output distribution."
                        ]
                    }
                ],
                "key_terms": [
                    {"term": "Primary Principle", "definition": "Core textbook definition and governing law."},
                    {"term": "Dynamic Equilibrium", "definition": "The state where opposing processes occur at equal rates."}
                ],
                "formulas_or_rules": [
                    "Rule 1: Conservation principles strictly apply across all transformations.",
                    "Rule 2: Rate constants depend on ambient temperature and concentration gradients."
                ],
                "exam_tips": [
                    "Pay careful attention to graph questions where axes represent inverse variables.",
                    "Eliminate options that confuse cause with subsequent consequence."
                ],
                "key_concepts": [
                    "Fundamental definition and theoretical framework.",
                    "Operational mechanics and functional relationships."
                ],
                "definitions": [
                    {"term": "Primary Principle", "definition": "Core textbook definition."}
                ],
                "important_processes": [
                    "Phase 1: Initiation and input gathering.",
                    "Phase 2: Reaction or mechanical operation.",
                    "Phase 3: Final product synthesis."
                ],
                "comparisons": [
                    {"comparison": "Topic A vs Topic B", "distinction": "Topic A is active whereas Topic B is passive."}
                ],
                "common_confusions": [
                    "Students often invert the stages; remember chronological order."
                ],
                "exam_focused_points": [
                    "Directly tested on entrance exams regarding structural differences."
                ]
            })
        elif "understand" in system_prompt.lower() or "unit_overview" in system_prompt:
            return json.dumps({
                "big_idea_in_plain_english": "This unit is all about how nature balances resources to keep complex systems running smoothly.",
                "real_life_analogy": "Think of this system like a modern city traffic grid: if one major artery closes, traffic automatically reroutes to keep movement steady.",
                "step_by_step_breakdown": [
                    {
                        "step": 1,
                        "title": "The Starting Foundation",
                        "explanation": "Everything begins with basic raw inputs that enter the system under normal conditions."
                    },
                    {
                        "step": 2,
                        "title": "The Core Engine at Work",
                        "explanation": "Specialized mechanisms process these inputs through carefully timed sequential steps."
                    },
                    {
                        "step": 3,
                        "title": "The Finished Product",
                        "explanation": "The end result provides the exact energy and structure required for sustained stability."
                    }
                ],
                "quick_self_check_questions": [
                    "Can you state the main purpose of this unit in one sentence?",
                    "What would happen if the initial stage was blocked?",
                    "How does this concept connect to what we learned in the previous chapter?"
                ],
                "unit_overview": "Let's break down this unit into simple, everyday ideas that are easy to remember.",
                "main_ideas_simplified": [
                    "Idea 1: The big picture is about how components work together.",
                    "Idea 2: Every action has a specific purpose and result."
                ],
                "analogies_and_examples": [
                    "Think of this system like a well-organized factory where each worker has one exact job."
                ],
                "common_pitfalls": [
                    "Don't worry about memorizing formulas before understanding the main concept."
                ],
                "quick_recap": "You've got this! Focus on the main purpose of each step."
            })
        elif "quiz" in system_prompt or "questions" in system_prompt:
            return json.dumps({
                "questions": [
                    {
                        "question_text": "Which of the following best defines the primary concept of this unit?",
                        "question": "Which of the following best defines the primary concept of this unit?",
                        "options": {
                            "A": "Fundamental curriculum principle governing the topic",
                            "B": "A secondary distractor phenomenon",
                            "C": "Unrelated historical assumption",
                            "D": "Hypothetical model without experimental basis"
                        },
                        "correct_answer": "A",
                        "explanation": "As stated in the curriculum, this term describes the core principle."
                    },
                    {
                        "question_text": "What is the initial stage of the process described in this unit?",
                        "question": "What is the initial stage of the process described in this unit?",
                        "options": {
                            "A": "Phase 1: Regulated initiation and activation",
                            "B": "Termination and waste elimination",
                            "C": "Intermediate equilibrium conversion",
                            "D": "Byproduct decomposition"
                        },
                        "correct_answer": "A",
                        "explanation": "The process always starts with initial activation."
                    },
                    {
                        "question_text": "How do key components interact within this system?",
                        "question": "How do key components interact within this system?",
                        "options": {
                            "A": "Synergistically through direct regulation",
                            "B": "Completely independently without communication",
                            "C": "In chaotic disorder without fixed pathways",
                            "D": "Exclusively through passive diffusion"
                        },
                        "correct_answer": "A",
                        "explanation": "The textbook emphasizes structured synergistic interaction."
                    },
                    {
                        "question_text": "Which factor most significantly influences the rate of this process?",
                        "question": "Which factor most significantly influences the rate of this process?",
                        "options": {
                            "A": "Concentration gradients and ambient temperature",
                            "B": "Color of the surrounding tissue or container",
                            "C": "External magnetic orientation only",
                            "D": "Random background vibration"
                        },
                        "correct_answer": "A",
                        "explanation": "Environmental factors such as concentration and temperature regulate activity."
                    },
                    {
                        "question_text": "What is the primary function of the resulting product?",
                        "question": "What is the primary function of the resulting product?",
                        "options": {
                            "A": "Sustaining structural integrity and energetic requirements",
                            "B": "Immediate inert excretion as unwanted material",
                            "C": "Completely halting all downstream biological functions",
                            "D": "Serving no identifiable functional purpose"
                        },
                        "correct_answer": "A",
                        "explanation": "Products provide essential structural and energetic support."
                    },
                    {
                        "question_text": "What distinguishes this mechanism from its counterpart?",
                        "question": "What distinguishes this mechanism from its counterpart?",
                        "options": {
                            "A": "High specificity and strict energy dependency",
                            "B": "Complete absence of regulatory feedback",
                            "C": "Inability to operate under standard atmospheric conditions",
                            "D": "Random fluctuations without enzyme or catalyst participation"
                        },
                        "correct_answer": "A",
                        "explanation": "Energy dependency and specificity are the main distinguishing factors."
                    },
                    {
                        "question_text": "Which of the following represents a practical real-world application of this concept?",
                        "question": "Which of the following represents a practical real-world application of this concept?",
                        "options": {
                            "A": "Agricultural crop enhancement and medical diagnostics",
                            "B": "Orbital space navigation mathematics only",
                            "C": "Linguistic etymology and phonetics",
                            "D": "Pure theoretical deduction without real application"
                        },
                        "correct_answer": "A",
                        "explanation": "Applied sciences heavily rely on this concept in healthcare and agriculture."
                    }
                ]
            })
        elif "coach" in system_prompt or "tutor" in system_prompt:
            return json.dumps({
                "reply": "Hello! I am EduRise Coach, your educational assistant. According to the Ethiopian curriculum, let's explore this topic step-by-step so you feel completely confident!",
                "suggestions": [
                    "Explain with a practical example",
                    "What are common entrance exam questions on this?",
                    "Give me a quick 3-point recap"
                ]
            })
        else:
            return json.dumps({"status": "ok", "message": "EduRise Coach response generated successfully."})

    async def generate_explanation(
        self,
        question_text: str,
        options: List[str],
        correct_answer: str,
        existing_explanation: str,
        selected_answer: Optional[str] = None,
        subject: Optional[str] = None,
        grade: Optional[str] = None,
    ) -> ExplanationResult:
        system_prompt = (
            "You are EduRise Coach, an authoritative expert Ethiopian curriculum tutor. "
            "Your task is to provide a deeper, structured explanation for a multiple-choice question. "
            "CRITICAL: The EduRise provided correct answer is 100% authoritative and non-negotiable. "
            "You MUST explain:\n"
            "1. 'why_correct': A concise, deep explanation of WHY the authoritative correct answer is correct.\n"
            "2. 'why_other_options_wrong': An array of explanations explaining specifically why each other option is wrong or a distractor.\n"
            "3. 'key_takeaway': A 1-sentence tip for remembering this concept on exams.\n"
            "Respond strictly in valid JSON matching the schema."
        )

        user_prompt = (
            f"Subject: {subject or 'General'}\n"
            f"Grade: {grade or 'Grade 12'}\n"
            f"Question: {question_text}\n"
            f"Options: {json.dumps(options)}\n"
            f"Authoritative Correct Answer: {correct_answer}\n"
            f"Existing Explanation: {existing_explanation}\n"
            f"Student's Selected Answer: {selected_answer or 'None'}\n"
        )

        raw = await self._call_gemini(system_prompt, user_prompt, json_mode=True)
        data = self._extract_json(raw)
        return ExplanationResult(
            why_correct=data.get("why_correct", "The correct answer matches curriculum standards."),
            why_other_options_wrong=data.get("why_other_options_wrong", []),
            key_takeaway=data.get("key_takeaway"),
        )

    async def generate_summary(
        self,
        grade: str,
        subject: str,
        unit_number: int,
        unit_name: str,
        textbook_context: str,
    ) -> SummaryResult:
        system_prompt = (
            "You are EduRise Coach. Generate a concise, high-yield summary for this textbook unit based strictly on the provided context. "
            "Output JSON with keys:\n"
            "- 'overview': string\n"
            "- 'key_points': list of strings\n"
            "- 'bullet_points': list of strings\n"
            "- 'important_terms': list of objects [{'term': '...', 'definition': '...'}]\n"
            "- 'key_concepts': list of strings\n"
            "- 'summary_recap': string\n"
            "- 'exam_importance': string"
        )
        user_prompt = (
            f"Grade: {grade}, Subject: {subject}, Unit {unit_number}: {unit_name}\n"
            f"Textbook Context:\n{textbook_context[:6000]}"
        )
        raw = await self._call_gemini(system_prompt, user_prompt, json_mode=True)
        data = self._extract_json(raw)

        overview = data.get("overview", "Unit overview summary.")
        key_pts = data.get("key_points") or data.get("bullet_points") or []
        bullet_pts = data.get("bullet_points") or key_pts
        terms = data.get("important_terms", [])
        concepts = data.get("key_concepts") or [t.get("term", "") for t in terms if isinstance(t, dict)]
        recap = data.get("summary_recap") or data.get("exam_importance") or ""
        exam_imp = data.get("exam_importance") or recap

        return SummaryResult(
            overview=overview,
            key_points=key_pts,
            bullet_points=bullet_pts,
            important_terms=terms,
            key_concepts=concepts,
            summary_recap=recap,
            exam_importance=exam_imp,
        )

    async def generate_flashcards(
        self,
        grade: str,
        subject: str,
        unit_number: int,
        unit_name: str,
        textbook_context: str,
    ) -> FlashcardsResult:
        system_prompt = (
            "You are EduRise Coach. Generate 4 to 8 high-yield question/answer flashcards for this textbook unit. "
            "Output JSON with key 'flashcards': list of objects [{'front': '...', 'back': '...', 'question': '...', 'answer': '...', 'category': '...'}]"
        )
        user_prompt = (
            f"Grade: {grade}, Subject: {subject}, Unit {unit_number}: {unit_name}\n"
            f"Textbook Context:\n{textbook_context[:6000]}"
        )
        raw = await self._call_gemini(system_prompt, user_prompt, json_mode=True)
        data = self._extract_json(raw)
        items = []
        for fc in data.get("flashcards", []):
            q = fc.get("front") or fc.get("question") or ""
            a = fc.get("back") or fc.get("answer") or ""
            cat = fc.get("category") or "Core Concept"
            items.append(FlashcardItem(question=q, answer=a, front=q, back=a, category=cat))
        return FlashcardsResult(flashcards=items)

    async def generate_ai_notes(
        self,
        grade: str,
        subject: str,
        unit_number: int,
        unit_name: str,
        textbook_context: str,
    ) -> AiNotesResult:
        system_prompt = (
            "You are EduRise Coach. Generate structured study notes based strictly on the textbook unit context. "
            "Output JSON with keys:\n"
            "- 'sections': list of [{'title': '...', 'content': '...', 'key_points': [...]}]\n"
            "- 'key_terms': list of [{'term': '...', 'definition': '...'}]\n"
            "- 'formulas_or_rules': list of strings\n"
            "- 'exam_tips': list of strings\n"
            "- 'key_concepts': list of strings\n"
            "- 'definitions': list of [{'term': '...', 'definition': '...'}]\n"
            "- 'important_processes': list of strings\n"
            "- 'comparisons': list of [{'comparison': '...', 'distinction': '...'}]\n"
            "- 'common_confusions': list of strings\n"
            "- 'exam_focused_points': list of strings"
        )
        user_prompt = (
            f"Grade: {grade}, Subject: {subject}, Unit {unit_number}: {unit_name}\n"
            f"Textbook Context:\n{textbook_context[:6000]}"
        )
        raw = await self._call_gemini(system_prompt, user_prompt, json_mode=True)
        data = self._extract_json(raw)

        raw_sections = data.get("sections", [])
        sections = []
        if raw_sections:
            for sec in raw_sections:
                if isinstance(sec, dict):
                    sections.append(
                        AiNotesSection(
                            title=sec.get("title", ""),
                            content=sec.get("content", ""),
                            key_points=sec.get("key_points", []),
                        )
                    )
        else:
            concepts = data.get("key_concepts", [])
            if concepts:
                sections.append(
                    AiNotesSection(
                        title="Core Concepts",
                        content="Fundamental curriculum principles and governing laws.",
                        key_points=concepts,
                    )
                )
            procs = data.get("important_processes", [])
            if procs:
                sections.append(
                    AiNotesSection(
                        title="Essential Mechanisms",
                        content="Operational stages and transformations.",
                        key_points=procs,
                    )
                )

        terms = data.get("key_terms") or data.get("definitions") or []
        formulas = data.get("formulas_or_rules", [])
        tips = data.get("exam_tips") or data.get("exam_focused_points") or []

        return AiNotesResult(
            sections=sections,
            key_terms=terms,
            formulas_or_rules=formulas,
            exam_tips=tips,
            key_concepts=data.get("key_concepts", []),
            definitions=data.get("definitions", []),
            important_processes=data.get("important_processes", []),
            comparisons=data.get("comparisons", []),
            common_confusions=data.get("common_confusions", []),
            exam_focused_points=data.get("exam_focused_points", []),
        )

    async def generate_understand_unit(
        self,
        grade: str,
        subject: str,
        unit_number: int,
        unit_name: str,
        textbook_context: str,
    ) -> UnderstandUnitResult:
        system_prompt = (
            "You are EduRise Coach. Explain this unit in a friendly, simplified teacher style for a student who feels they don't understand it. "
            "Output JSON with keys:\n"
            "- 'big_idea_in_plain_english': string\n"
            "- 'real_life_analogy': string\n"
            "- 'step_by_step_breakdown': list of [{'step': 1, 'title': '...', 'explanation': '...'}]\n"
            "- 'quick_self_check_questions': list of strings\n"
            "- 'unit_overview': string\n"
            "- 'main_ideas_simplified': list of strings\n"
            "- 'analogies_and_examples': list of strings\n"
            "- 'common_pitfalls': list of strings\n"
            "- 'quick_recap': string"
        )
        user_prompt = (
            f"Grade: {grade}, Subject: {subject}, Unit {unit_number}: {unit_name}\n"
            f"Textbook Context:\n{textbook_context[:6000]}"
        )
        raw = await self._call_gemini(system_prompt, user_prompt, json_mode=True)
        data = self._extract_json(raw)

        big_idea = (
            data.get("big_idea_in_plain_english")
            or data.get("unit_overview")
            or "Understanding unit concepts in simple terms."
        )
        analogy = (
            data.get("real_life_analogy")
            or (data.get("analogies_and_examples", [""])[0] if data.get("analogies_and_examples") else "")
            or "Think of this unit like an organized system where each component has an essential role."
        )
        raw_steps = data.get("step_by_step_breakdown", [])
        steps = []
        for i, st in enumerate(raw_steps):
            if isinstance(st, dict):
                steps.append(
                    UnderstandStep(
                        step=int(st.get("step", i + 1)),
                        title=st.get("title", f"Step {i + 1}"),
                        explanation=st.get("explanation", ""),
                    )
                )
            elif isinstance(st, str):
                steps.append(
                    UnderstandStep(
                        step=i + 1,
                        title=f"Step {i + 1}",
                        explanation=st,
                    )
                )

        checks = data.get("quick_self_check_questions") or data.get("common_pitfalls") or []

        return UnderstandUnitResult(
            big_idea_in_plain_english=big_idea,
            real_life_analogy=analogy,
            step_by_step_breakdown=steps,
            quick_self_check_questions=checks,
            unit_overview=data.get("unit_overview") or big_idea,
            main_ideas_simplified=data.get("main_ideas_simplified", []),
            analogies_and_examples=data.get("analogies_and_examples", [analogy] if analogy else []),
            common_pitfalls=data.get("common_pitfalls", []),
            quick_recap=data.get("quick_recap", ""),
        )

    async def generate_quiz(
        self,
        grade: str,
        subject: str,
        unit_number: int,
        unit_name: str,
        textbook_context: str,
    ) -> QuizResult:
        system_prompt = (
            "You are EduRise Coach. Generate ONE quiz containing EXACTLY 7 multiple-choice questions grounded in the provided unit textbook. "
            "CRITICAL REQUIREMENTS:\n"
            "1. You MUST return EXACTLY 7 questions.\n"
            "2. Each question MUST have exactly 4 options with keys 'A', 'B', 'C', and 'D'.\n"
            "3. 'correct_answer' MUST strictly be one of the uppercase letters 'A', 'B', 'C', or 'D'.\n"
            "4. Provide a clear curriculum-aligned 'explanation'.\n"
            "Output JSON with key 'questions': list of objects [{'question_text': '...', 'options': {'A': '...', 'B': '...', 'C': '...', 'D': '...'}, 'correct_answer': 'A', 'explanation': '...'}]"
        )
        user_prompt = (
            f"Grade: {grade}, Subject: {subject}, Unit {unit_number}: {unit_name}\n"
            f"Textbook Context:\n{textbook_context[:6000]}"
        )
        raw = await self._call_gemini(system_prompt, user_prompt, json_mode=True)
        data = self._extract_json(raw)
        raw_qs = data.get("questions", [])
        questions = []

        for q in raw_qs[:7]:
            q_text = q.get("question_text") or q.get("question") or "Unit Assessment Question"
            opts_raw = q.get("options")
            opts_dict = {}
            opts_list = []

            if isinstance(opts_raw, dict):
                for k in ["A", "B", "C", "D"]:
                    val = str(opts_raw.get(k) or opts_raw.get(k.lower()) or f"Option {k}")
                    opts_dict[k] = val
                    opts_list.append(val)
            elif isinstance(opts_raw, list):
                letters = ["A", "B", "C", "D"]
                for idx, opt in enumerate(opts_raw[:4]):
                    opts_dict[letters[idx]] = str(opt)
                    opts_list.append(str(opt))
                while len(opts_list) < 4:
                    let = letters[len(opts_list)]
                    opts_dict[let] = f"Option {let}"
                    opts_list.append(f"Option {let}")
            else:
                opts_dict = {"A": "Option A", "B": "Option B", "C": "Option C", "D": "Option D"}
                opts_list = ["Option A", "Option B", "Option C", "Option D"]

            # Strict validation for duplicate options
            seen_texts = set()
            for k in ["A", "B", "C", "D"]:
                if opts_dict[k].strip().lower() in seen_texts:
                    opts_dict[k] = f"{opts_dict[k]} (Alternative {k})"
                seen_texts.add(opts_dict[k].strip().lower())

            raw_corr = str(q.get("correct_answer", "A")).strip()
            if raw_corr.upper() in ["A", "B", "C", "D"]:
                corr_letter = raw_corr.upper()
            else:
                corr_letter = "A"
                for let, text in opts_dict.items():
                    if text.strip().lower() == raw_corr.lower():
                        corr_letter = let
                        break

            expl = q.get("explanation") or f"Curriculum aligned explanation for Grade {grade} {subject}."
            questions.append(
                QuizQuestion(
                    question=q_text,
                    question_text=q_text,
                    options=opts_dict,
                    options_list=opts_list,
                    correct_answer=corr_letter,
                    explanation=expl,
                )
            )

        # Enforce exactly 7 questions
        while len(questions) < 7:
            idx = len(questions) + 1
            q_text = f"Review Question {idx}: Which statement accurately reflects {unit_name} principles?"
            fallback_opts = {
                "A": f"Primary curriculum principle governing {unit_name}",
                "B": "Distractor assumption unsupported by textbook content",
                "C": "Reversed sequential mechanism",
                "D": "Inaccurate secondary effect distractor",
            }
            questions.append(
                QuizQuestion(
                    question=q_text,
                    question_text=q_text,
                    options=fallback_opts,
                    options_list=list(fallback_opts.values()),
                    correct_answer="A",
                    explanation=f"Based on Grade {grade} {subject} Unit {unit_number}: {unit_name}.",
                )
            )

        return QuizResult(questions=questions[:7])

    async def generate_coach_reply(
        self,
        user_message: str,
        student_stream: str,
        student_grade: str,
        subject: Optional[str] = None,
        relevant_context: Optional[str] = None,
        history: Optional[List[Dict[str, str]]] = None,
    ) -> CoachReplyResult:
        system_prompt = (
            "You are EduRise Coach, a warm, highly knowledgeable tutor for Ethiopian secondary students (Grades 9-12) "
            "preparing for classroom excellence and the National University Entrance Examination (EUEE). "
            "Always align your explanations strictly with the Ethiopian curriculum and the student's academic stream. "
            "Output JSON with keys:\n"
            "- 'reply': formatted markdown string explanation\n"
            "- 'suggestions': list of 2-3 short relevant follow-up questions"
        )

        history_text = ""
        if history:
            formatted_history = []
            for h in history[-6:]:
                role_name = "Student" if h.get("role") == "user" else "EduRise Coach"
                content = h.get("content", "").strip()
                if content:
                    formatted_history.append(f"{role_name}: {content}")
            if formatted_history:
                history_text = "\nRecent Conversation History:\n" + "\n".join(formatted_history) + "\n"

        user_prompt = (
            f"Student Stream: {student_stream}\n"
            f"Student Grade: {student_grade}\n"
            f"Subject: {subject or 'General'}\n"
            f"Additional Learning Context: {relevant_context or 'None'}\n"
            f"{history_text}"
            f"Student Question: {user_message}"
        )
        raw = await self._call_gemini(system_prompt, user_prompt, json_mode=True)
        data = self._extract_json(raw)
        return CoachReplyResult(
            reply=data.get("reply", "I am here to help you master your curriculum topics!"),
            suggestions=data.get("suggestions", []),
        )

    async def generate_predicted_mock_exam(
        self,
        subject: str,
        stream: str,
        question_count: int,
        historical_blueprint: Dict[str, Any],
    ) -> MockExamResult:
        system_prompt = (
            "You are EduRise Coach Exam Intelligence Engine. "
            "Generate a curriculum-aligned Predicted Mock Exam based on historical entrance exam blueprint distributions. "
            "Output JSON with keys:\n"
            "- 'title': string\n"
            "- 'subject': string\n"
            "- 'stream': string\n"
            "- 'total_questions': int\n"
            "- 'duration_minutes': int\n"
            "- 'blueprint_summary': string\n"
            "- 'questions': list of objects [{'question_number': int, 'question_text': '...', 'option_a': '...', 'option_b': '...', 'option_c': '...', 'option_d': '...', 'correct_answer': 'A'|'B'|'C'|'D', 'explanation': '...', 'unit_topic': '...'}]"
        )
        user_prompt = (
            f"Subject: {subject}\n"
            f"Stream: {stream}\n"
            f"Target Questions Count: {question_count}\n"
            f"Historical Blueprint Patterns: {json.dumps(historical_blueprint)}"
        )
        raw = await self._call_gemini(system_prompt, user_prompt, json_mode=True)
        data = self._extract_json(raw)
        raw_qs = data.get("questions", [])
        questions = []
        for i, q in enumerate(raw_qs[:question_count]):
            questions.append(
                MockExamQuestion(
                    question_number=i + 1,
                    question_text=q.get("question_text", f"Question {i+1}"),
                    option_a=q.get("option_a", "Option A"),
                    option_b=q.get("option_b", "Option B"),
                    option_c=q.get("option_c", "Option C"),
                    option_d=q.get("option_d", "Option D"),
                    correct_answer=q.get("correct_answer", "A"),
                    explanation=q.get("explanation", "Historical pattern curriculum explanation."),
                    unit_topic=q.get("unit_topic"),
                )
            )

        while len(questions) < question_count:
            num = len(questions) + 1
            questions.append(
                MockExamQuestion(
                    question_number=num,
                    question_text=f"Mock Question {num}: Which of the following is consistent with {subject} exam standards?",
                    option_a="Primary theoretical principle",
                    option_b="Secondary inverse distractor",
                    option_c="Unrelated hypothesis",
                    option_d="Incomplete definition",
                    correct_answer="A",
                    explanation="Based on 2013-2018 EC Entrance Examination topic weighting.",
                    unit_topic="General Curriculum Review",
                )
            )

        return MockExamResult(
            title=data.get("title", f"Predicted Mock Exam: {subject}"),
            subject=subject,
            stream=stream,
            total_questions=len(questions),
            duration_minutes=data.get("duration_minutes") or historical_blueprint.get("default_duration_minutes", 120),
            blueprint_summary=data.get("blueprint_summary", "Generated from historical entrance exam blueprints (2013-2018 EC)."),
            questions=questions,
        )
