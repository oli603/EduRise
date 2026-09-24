from abc import ABC, abstractmethod
from typing import Dict, Any, List, Optional
from pydantic import BaseModel


class ExplanationResult(BaseModel):
    why_correct: str
    why_other_options_wrong: List[str]
    key_takeaway: Optional[str] = None


class FlashcardItem(BaseModel):
    question: str
    answer: str
    front: str = ""
    back: str = ""
    category: str = "Core Concept"


class FlashcardsResult(BaseModel):
    flashcards: List[FlashcardItem]


class SummaryResult(BaseModel):
    overview: str
    key_points: List[str] = []
    bullet_points: List[str] = []
    important_terms: List[Dict[str, str]] = []
    key_concepts: List[str] = []
    summary_recap: str = ""
    exam_importance: str = ""


class AiNotesSection(BaseModel):
    title: str
    content: str
    key_points: List[str] = []


class AiNotesResult(BaseModel):
    sections: List[AiNotesSection] = []
    key_terms: List[Dict[str, str]] = []
    formulas_or_rules: List[str] = []
    exam_tips: List[str] = []
    key_concepts: List[str] = []
    definitions: List[Dict[str, str]] = []
    important_processes: List[str] = []
    comparisons: List[Dict[str, str]] = []
    common_confusions: List[str] = []
    exam_focused_points: List[str] = []


class UnderstandStep(BaseModel):
    step: int
    title: str
    explanation: str


class UnderstandUnitResult(BaseModel):
    big_idea_in_plain_english: str = ""
    real_life_analogy: str = ""
    step_by_step_breakdown: List[UnderstandStep] = []
    quick_self_check_questions: List[str] = []
    unit_overview: str = ""
    main_ideas_simplified: List[str] = []
    analogies_and_examples: List[str] = []
    common_pitfalls: List[str] = []
    quick_recap: str = ""


class QuizQuestion(BaseModel):
    question: str
    question_text: str = ""
    options: Dict[str, str] = {}
    options_list: List[str] = []
    correct_answer: str = "A"
    explanation: str = ""


class QuizResult(BaseModel):
    questions: List[QuizQuestion]


class CoachReplyResult(BaseModel):
    reply: str
    suggestions: List[str] = []


class MockExamQuestion(BaseModel):
    question_number: int
    question_text: str
    option_a: str
    option_b: str
    option_c: str
    option_d: str
    correct_answer: str
    explanation: str
    unit_topic: Optional[str] = None


class MockExamResult(BaseModel):
    title: str
    subject: str
    stream: str
    total_questions: int
    duration_minutes: int
    blueprint_summary: str
    questions: List[MockExamQuestion]


class AIProvider(ABC):
    @abstractmethod
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
        pass

    @abstractmethod
    async def generate_summary(
        self,
        grade: str,
        subject: str,
        unit_number: int,
        unit_name: str,
        textbook_context: str,
    ) -> SummaryResult:
        pass

    @abstractmethod
    async def generate_flashcards(
        self,
        grade: str,
        subject: str,
        unit_number: int,
        unit_name: str,
        textbook_context: str,
    ) -> FlashcardsResult:
        pass

    @abstractmethod
    async def generate_ai_notes(
        self,
        grade: str,
        subject: str,
        unit_number: int,
        unit_name: str,
        textbook_context: str,
    ) -> AiNotesResult:
        pass

    @abstractmethod
    async def generate_understand_unit(
        self,
        grade: str,
        subject: str,
        unit_number: int,
        unit_name: str,
        textbook_context: str,
    ) -> UnderstandUnitResult:
        pass

    @abstractmethod
    async def generate_quiz(
        self,
        grade: str,
        subject: str,
        unit_number: int,
        unit_name: str,
        textbook_context: str,
    ) -> QuizResult:
        """
        MUST generate exactly 7 multiple-choice questions grounded in the unit textbook.
        """
        pass

    @abstractmethod
    async def generate_coach_reply(
        self,
        user_message: str,
        student_stream: str,
        student_grade: str,
        subject: Optional[str] = None,
        relevant_context: Optional[str] = None,
        history: Optional[List[Dict[str, str]]] = None,
    ) -> CoachReplyResult:
        pass

    @abstractmethod
    async def generate_predicted_mock_exam(
        self,
        subject: str,
        stream: str,
        question_count: int,
        historical_blueprint: Dict[str, Any],
    ) -> MockExamResult:
        pass
