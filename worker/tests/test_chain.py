from selah_worker.__main__ import next_job


def test_chain_queues_the_next_step_with_the_rest():
    job = {"sermon_id": "s1", "created_by": "u1", "payload": {"language_code": "es", "chain": [
        {"step": "analysis"}, {"step": "summary", "payload": {"output_language": "pt"}}]}}
    follow_up = next_job(job)
    assert follow_up["step"] == "analysis"
    assert follow_up["sermon_id"] == "s1" and follow_up["created_by"] == "u1"
    assert follow_up["payload"] == {"chain": [{"step": "summary", "payload": {"output_language": "pt"}}]}
    last = next_job(next_job(follow_up))
    assert last is None


def test_job_without_chain_ends():
    assert next_job({"sermon_id": "s1", "payload": {}}) is None
