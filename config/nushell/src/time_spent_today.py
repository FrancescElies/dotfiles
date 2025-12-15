# pip install aw-client
import socket
from datetime import datetime, time, timedelta
from typing import NamedTuple

import aw_client


def get_time_worked(day: datetime):
    bucket_id = f"aw-watcher-afk_{socket.gethostname()}"

    daystart = datetime.combine(day.date(), time())
    dayend = daystart + timedelta(days=1)

    awc = aw_client.ActivityWatchClient("testclient")
    events = awc.get_events(bucket_id, start=daystart, end=dayend)
    events = [e for e in events if e.data["status"] == "not-afk"]
    if not events:
        return None
    timestamps = sorted([t for e in events if (t := e.get("timestamp", None))])
    start = timestamps[0]
    end = timestamps[-1]
    total_duration = sum((e.duration for e in events), timedelta())

    class Time(NamedTuple):
        start: datetime
        end: datetime
        total_duration: timedelta

    return Time(start, end, total_duration)


if __name__ == "__main__":
    # Set this to your AFK bucket

    start_date = datetime(2025, 7, 1)
    end_date = datetime.now()
    for n in range((end_date - start_date).days + 1):
        current_date = start_date + timedelta(days=n)
        time_worked = get_time_worked(current_date)
        if not time_worked:
            continue
        (start, end, total_duration) = time_worked
        print(
            f"{current_date.strftime('%Y-%m-%d')} coding={total_duration.seconds / 3600:.1f}hours start={start.hour + 2}:{start.minute} end={end.hour + 2}:{end.minute}"
        )
