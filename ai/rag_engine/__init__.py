__all__ = ["get_recommendation", "stream_recommendation"]


def get_recommendation(*args, **kwargs):
    from ai.rag_engine.rag_pipeline import get_recommendation as _get_recommendation

    return _get_recommendation(*args, **kwargs)


def stream_recommendation(*args, **kwargs):
    from ai.rag_engine.rag_pipeline import stream_recommendation as _stream_recommendation

    return _stream_recommendation(*args, **kwargs)
