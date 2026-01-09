import re
import os
from typing import Dict, Any, List

# Patterns for common high-risk secrets
PATTERNS = {
    "AWS Access Key": r"(?<![A-Z0-9])[A-Z0-9]{20}(?![A-Z0-9])",  # Basic heuristic
    "AWS Secret": r"(?<![A-Za-z0-9/+=])[A-Za-z0-9/+=]{40}(?![A-Za-z0-9/+=])",
    "Google API Key": r"AIza[0-9A-Za-z\\-_]{35}",
    "Generic Private Key": r"-----BEGIN PRIVATE KEY-----",
    "OpenAI API Key": r"sk-[a-zA-Z0-9]{48}",
    "Hardcoded Password": r"(password|passwd|pwd)\s*[:=]\s*['\"][^'\"]{3,}['\"]",
    "DB Connection String": r"mysql://|postgresql://|mongodb://"
}

# Files to skip (example configs, docs, tests often have placeholder keys)
SKIP_FILES = (
    ".env.example", ".env.sample", "example.env", "config.example",
    ".png", ".jpg", ".lock", ".pyc", ".md", ".txt", ".rst"
)

SKIP_FOLDERS = ("test", "tests", "__tests__", "docs", "documentation", "examples", "node_modules", ".git")

def scan_for_secrets(repo_path: str) -> Dict[str, Any]:
    leaks = []
    
    # Walk through files
    for root, _, files in os.walk(repo_path):
        # Skip test/docs/example folders
        if any(skip_folder in root.lower() for skip_folder in SKIP_FOLDERS):
            continue
            
        for f in files:
            f_lower = f.lower()
            # Skip hidden files, images, docs, and example config files
            if f.startswith(".") or f_lower.endswith(SKIP_FILES):
                continue
            
            path = os.path.join(root, f)
            try:
                with open(path, "r", encoding="utf-8", errors="ignore") as file_in:
                    lines = file_in.readlines()
                    
                for i, line in enumerate(lines):
                    # Skip commented lines
                    stripped = line.strip()
                    if stripped.startswith(("#", "//", "/*", "*", "'", '"')):
                        continue
                        
                    for name, pattern in PATTERNS.items():
                        if re.search(pattern, line):
                            # Record minute detail: File, Line #, Type
                            leaks.append({
                                "file": f,
                                "path": path.replace(repo_path, ""), # Relative path
                                "line_number": i + 1,
                                "type": name,
                                "snippet": line.strip()[:50] + "..." # Truncated for display
                            })
            except Exception:
                continue
                
    # Calculate Score (100 = Safe, -10 per leak, max penalty 80)
    # Projects with some leaks shouldn't instantly get 0
    security_penalty = min(80, len(leaks) * 10)
    
    return {
        "score": max(20, 100 - security_penalty),  # Minimum score of 20
        "leak_count": len(leaks),
        "details": leaks
    }