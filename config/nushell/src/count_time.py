from time import perf_counter
from contextlib import contextmanager


@contextmanager
def count_time(message: str):
    start = perf_counter()
    yield
    print(f"{message} {perf_counter() - start} seconds")
    breakpoint()
