"""Interactive walker for citation_manual_queue.

One-shot tool for working through the small handful of planets that
failed every automated tier in resolve_citations.py. For each row,
shows the planet, parsed citation link, and notes, then prompts:

  [d]elete  remove from queue (decision: not worth chasing further)
  [s]kip    leave in queue, advance
  [q]uit    exit

There is intentionally no "resolve" action here: real resolution
requires fixing the upstream disc_refname or hand-inserting into
publications + planet_publications, both of which are easier to do
in psql while staring at the row.

Delete this file once the queue is empty.

Run:
    python -m etl.walk_manual_queue
"""

from __future__ import annotations

import os
import re
import sys

import psycopg
from dotenv import load_dotenv
from psycopg.rows import dict_row

load_dotenv()


def parse_refname(raw: str | None) -> tuple[str, str | None]:
    if not raw:
        return ("", None)
    m = re.search(r"href=([^\s>]+)[^>]*>\s*([^<]+?)\s*</a>", raw, re.IGNORECASE)
    if not m:
        text = re.sub(r"<[^>]+>", "", raw).strip()
        return (text, None)
    return (m.group(2).strip(), m.group(1))


def prompt(msg: str) -> str:
    try:
        return input(msg).strip().lower()
    except EOFError:
        return "q"


def main() -> int:
    with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
        with conn.cursor(row_factory=dict_row) as cur:
            cur.execute(
                "SELECT pl_name, disc_refname, notes, created_at "
                "FROM citation_manual_queue ORDER BY pl_name"
            )
            rows = cur.fetchall()

        if not rows:
            print("Queue is empty. Delete etl/walk_manual_queue.py.")
            return 0

        print(f"{len(rows)} row(s) in citation_manual_queue\n")

        for i, row in enumerate(rows, start=1):
            text, url = parse_refname(row["disc_refname"])
            print(f"[{i}/{len(rows)}] {row['pl_name']}")
            print(f"    citation : {text or '(no parsed text)'}")
            if url:
                print(f"    url      : {url}")
            if row["notes"]:
                print(f"    notes    : {row['notes']}")
            print(f"    queued   : {row['created_at']:%Y-%m-%d}")

            while True:
                choice = prompt("    action [d=delete, s=skip, q=quit]: ")
                if choice in ("d", "s", "q"):
                    break
                print("    unknown action")

            if choice == "q":
                print("quitting")
                break
            if choice == "s":
                print("    skipped\n")
                continue
            if choice == "d":
                confirm = prompt(f"    DELETE {row['pl_name']} from queue? [y/N]: ")
                if confirm == "y":
                    with conn.cursor() as cur:
                        cur.execute(
                            "DELETE FROM citation_manual_queue WHERE pl_name = %s",
                            (row["pl_name"],),
                        )
                    conn.commit()
                    print(f"    deleted {row['pl_name']}\n")
                else:
                    print("    cancelled\n")

    return 0


if __name__ == "__main__":
    sys.exit(main())
