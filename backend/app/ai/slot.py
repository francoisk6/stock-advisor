"""The model serves one request at a time (OLLAMA_NUM_PARALLEL=1): chat, explanations and
digests share this slot so they queue instead of competing for the CPU."""

import asyncio

slot = asyncio.Semaphore(1)
waiting = 0  # requests queued behind the current one (for "you're number N in line")
