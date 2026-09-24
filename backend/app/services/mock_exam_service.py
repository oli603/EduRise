from typing import Dict, Any, Optional
from ..providers.base_provider import AIProvider
from ..providers.gemini_provider import GeminiProvider
from .cache_service import CacheService

# Standard Ethiopian Entrance Examination blueprints based on historical 2013-2018 EC exam patterns
HISTORICAL_BLUEPRINTS = {
    "Biology": {
        "topics_weight": {
            "Cell Biology & Molecular Genetics": 0.25,
            "Human Biology & Physiology": 0.25,
            "Ecology, Environment & Conservation": 0.20,
            "Genetics & Evolution": 0.15,
            "Microbiology & Biotechnology": 0.15,
        },
        "difficulty_distribution": {"easy": 0.30, "medium": 0.50, "hard": 0.20},
        "historical_range": "2013-2018 EC",
        "default_question_count": 50,
        "default_duration_minutes": 120,
    },
    "Physics": {
        "topics_weight": {
            "Mechanics & Vectors": 0.30,
            "Electricity & Magnetism": 0.25,
            "Waves, Optics & Sound": 0.20,
            "Thermodynamics & Heat": 0.15,
            "Modern Physics & Atomic Structure": 0.10,
        },
        "difficulty_distribution": {"easy": 0.25, "medium": 0.55, "hard": 0.20},
        "historical_range": "2013-2018 EC",
        "default_question_count": 50,
        "default_duration_minutes": 120,
    },
    "Chemistry": {
        "topics_weight": {
            "Chemical Equilibrium & Kinetics": 0.25,
            "Atomic Structure & Periodic Properties": 0.20,
            "Electrochemistry": 0.20,
            "Organic Chemistry & Polymers": 0.20,
            "Solutions & Acid-Base Chemistry": 0.15,
        },
        "difficulty_distribution": {"easy": 0.30, "medium": 0.50, "hard": 0.20},
        "historical_range": "2013-2018 EC",
        "default_question_count": 50,
        "default_duration_minutes": 120,
    },
    "Mathematics": {
        "topics_weight": {
            "Calculus (Limits, Derivatives, Integrals)": 0.30,
            "Algebra, Sequences & Series": 0.25,
            "Coordinate Geometry & Vectors": 0.20,
            "Trigonometry & Functions": 0.15,
            "Statistics & Probability": 0.10,
        },
        "difficulty_distribution": {"easy": 0.25, "medium": 0.50, "hard": 0.25},
        "historical_range": "2013-2018 EC",
        "default_question_count": 45,
        "default_duration_minutes": 180,
    },
    "English": {
        "topics_weight": {
            "Grammar & Syntax": 0.35,
            "Reading Comprehension & Contextual Inference": 0.30,
            "Vocabulary & Word Formation": 0.20,
            "Communication & Conversation Skills": 0.15,
        },
        "difficulty_distribution": {"easy": 0.30, "medium": 0.50, "hard": 0.20},
        "historical_range": "2013-2018 EC",
        "default_question_count": 60,
        "default_duration_minutes": 120,
    },
    "Scholastic Aptitude Test": {
        "topics_weight": {
            "Verbal Reasoning & Analogies": 0.35,
            "Quantitative & Numerical Reasoning": 0.35,
            "Logical & Analytical Deduction": 0.30,
        },
        "difficulty_distribution": {"easy": 0.25, "medium": 0.50, "hard": 0.25},
        "historical_range": "2013-2018 EC",
        "default_question_count": 60,
        "default_duration_minutes": 120,
    },
    "Economics": {
        "topics_weight": {
            "Microeconomics & Consumer Theory": 0.30,
            "Macroeconomics & National Income": 0.30,
            "Fiscal & Monetary Policy": 0.20,
            "International Trade & Economic Development": 0.20,
        },
        "difficulty_distribution": {"easy": 0.30, "medium": 0.50, "hard": 0.20},
        "historical_range": "2013-2018 EC",
        "default_question_count": 50,
        "default_duration_minutes": 120,
    },
    "Geography": {
        "topics_weight": {
            "Physical Geography & Climatology": 0.30,
            "Human & Economic Geography": 0.30,
            "Map Work & Geographic Information Systems": 0.20,
            "Environmental Management & Ethiopia": 0.20,
        },
        "difficulty_distribution": {"easy": 0.30, "medium": 0.50, "hard": 0.20},
        "historical_range": "2013-2018 EC",
        "default_question_count": 50,
        "default_duration_minutes": 120,
    },
    "History": {
        "topics_weight": {
            "Modern Ethiopian History (1855-Present)": 0.40,
            "African History & Decolonization": 0.30,
            "World History & International Relations": 0.30,
        },
        "difficulty_distribution": {"easy": 0.30, "medium": 0.50, "hard": 0.20},
        "historical_range": "2013-2018 EC",
        "default_question_count": 50,
        "default_duration_minutes": 120,
    },
    "Civics": {
        "topics_weight": {
            "Democratic Systems & Rule of Law": 0.35,
            "Human Rights & Constitutionalism": 0.35,
            "Patriotism, Ethics & Development": 0.30,
        },
        "difficulty_distribution": {"easy": 0.30, "medium": 0.50, "hard": 0.20},
        "historical_range": "2013-2018 EC",
        "default_question_count": 50,
        "default_duration_minutes": 120,
    },
    "General": {
        "topics_weight": {"General Curriculum Review": 1.0},
        "difficulty_distribution": {"easy": 0.30, "medium": 0.50, "hard": 0.20},
        "historical_range": "2013-2018 EC",
        "default_question_count": 50,
        "default_duration_minutes": 120,
    }
}


class MockExamService:
    def __init__(self, provider: Optional[AIProvider] = None):
        self.provider = provider or GeminiProvider()

    async def get_predicted_mock_exam(
        self,
        subject: str,
        stream: str = "natural",
        question_count: int = 50,
        version: str = "1",
    ) -> Dict[str, Any]:
        cache_key = CacheService.generate_cache_key(
            content_id=f"mock:{subject}:{stream}:{question_count}",
            content_version=version,
            feature_type="predicted_mock_exam",
        )
        cached = CacheService.get(cache_key)
        if cached:
            return {"source": "cache", **cached}

        blueprint = HISTORICAL_BLUEPRINTS.get(subject, HISTORICAL_BLUEPRINTS["General"])
        target_count = question_count if question_count > 0 else blueprint.get("default_question_count", 50)
        
        result = await self.provider.generate_predicted_mock_exam(
            subject=subject,
            stream=stream,
            question_count=target_count,
            historical_blueprint=blueprint,
        )
        if not result.duration_minutes or result.duration_minutes <= 0:
            result.duration_minutes = blueprint.get("default_duration_minutes", 120)
            
        data = result.model_dump()
        CacheService.set(
            cache_key=cache_key,
            data=data,
            content_id=f"mock:{subject}:{stream}",
            content_version=version,
            feature_type="predicted_mock_exam",
        )
        return {"source": "generated", **data}
