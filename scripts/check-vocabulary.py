#!/usr/bin/env python3
"""Check the learning vocabulary independently of the Color runtime."""
import copy
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def load(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))

def normalize(value):
    return re.sub(r"[_.\s-]+", "", value.casefold())

def check(lib, roles, laws):
    def require(ok, msg):
        if not ok:
            raise ValueError(msg)
    sources = lib["sources"]
    require(all(isinstance(v, str) and v.startswith("https://") for v in sources.values()), "invalid source")
    domains = {}
    for d in lib["domains"]:
        require(d["id"] not in domains and d["definition"].strip() and d["title"].strip(), "duplicate or incomplete domain")
        require(d["reference_ids"] and all(k in sources for k in d["reference_ids"]), "missing source reference")
        domains[d["id"]] = d
    ids, labels = {}, {}
    for t in lib["terms"]:
        key = t["id"]
        require(re.fullmatch(r"[a-z][a-z0-9_]*", key) and key not in ids, "duplicate or invalid ID: " + key)
        require(t["domain"] in domains and t["definition"].strip() and t["example"].strip(), "incomplete term: " + key)
        require(set(t) == {"id", "domain", "definition", "example", "aliases"}, "unexpected term field")
        require(isinstance(t["aliases"], list), "invalid aliases")
        ids[key] = t
        for label in [key] + t["aliases"]:
            n = normalize(label)
            require(n and (n not in labels or labels[n] == key), "ambiguous label: " + label)
            labels[n] = key
    c = lib["classification"]
    require(set(c["role_to_term"]) == {r["role"] for r in roles}, "role coverage mismatch")
    require(all(v in ids for v in c["role_to_term"].values()), "unknown role concept")
    require(set(c["legacy_hierarchies"]) == set(laws["allowed_hierarchies"]), "hierarchy coverage mismatch")
    require({r["category"] for r in roles} <= set(c["legacy_categories"]), "category coverage mismatch")
    require(all(set(r) <= set(c["fields"]) for r in roles), "field coverage mismatch")
    edges, subtype = set(), {}
    for r in lib["relations"]:
        a, typ, b = r["from"], r["type"], r["to"]
        require(a in ids and b in ids and typ in c["relation_types"], "invalid relation")
        require((a, typ, b) not in edges, "duplicate relation")
        edges.add((a, typ, b))
        if typ == "is_a":
            subtype.setdefault(a, set()).add(b)
    def visit(node, seen):
        require(node not in seen, "subtype cycle")
        for parent in subtype.get(node, set()):
            visit(parent, seen | {node})
    for node in subtype:
        visit(node, set())
    return len(ids), len(domains), len(edges)

def main():
    lib = load("docs/vocabulary.json")
    roles = load("ctl_environment_template/color_roles.json.template")
    laws = load("ctl_environment_template/laws/color/color-laws.json.template")
    counts = check(lib, roles, laws)
    # Verify the checker rejects independent malformed cases.
    def reject(change):
        bad = copy.deepcopy(lib)
        change(bad)
        try:
            check(bad, roles, laws)
        except ValueError:
            return
        raise AssertionError("negative control was accepted")
    reject(lambda x: x["terms"].append(copy.deepcopy(x["terms"][0])))
    reject(lambda x: x["terms"][1]["aliases"].append(x["terms"][0]["id"]))
    reject(lambda x: x["domains"][0]["reference_ids"].append("missing"))
    reject(lambda x: x["terms"][0].update(definition=""))
    reject(lambda x: x["classification"]["role_to_term"].pop("directory"))
    reject(lambda x: x["classification"]["legacy_hierarchies"].pop("parent"))
    reject(lambda x: x["relations"].append({"from":"missing","type":"is_a","to":"file"}))
    reject(lambda x: x["relations"].append({"from":"file","type":"is_a","to":"script"}))
    print(f"Vocabulary PASS: {counts[0]} terms, {counts[1]} domains, {counts[2]} relationships; 8 negative controls.")
if __name__ == "__main__":
    main()
