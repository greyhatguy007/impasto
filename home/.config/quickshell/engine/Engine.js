.pragma library

// ╭──────────────────────────────────────────────────────────────────────────╮
// │   E N G I N E   ·   formatting and reading                               │
// │   what a definition's templates and values mean, in QML                  │
// ╰──────────────────────────────────────────────────────────────────────────╯
//
// The one place a definition's strings become text. `widgets.py` checks that
// every `{name}` refers to a value the sources answer, so this side only has
// to be right about the rest: a dotted path, and a format spec as far as a
// widget needs one — `.1f`, `d`, `s`, `%`.

var PLACEHOLDER = /\{([A-Za-z_][A-Za-z0-9_.]*)(?::([^{}]*))?\}/g

// What a reading that is not there yet draws. A dash, so a widget that is
// still asking its source looks empty rather than wrong.
var MISSING = "—"

// `cpu.total`, `disks[0].used` or a plain name, into the readings.
function lookup(values, path) {
    if (!values || !path)
        return undefined
    var at = values
    var steps = String(path).split(".")
    for (var index = 0; index < steps.length; index++) {
        if (at === null || at === undefined || typeof at !== "object")
            return undefined
        at = at[steps[index]]
    }
    return at
}

// One reading, as text.
function one(spec, value) {
    if (value === undefined || value === null)
        return MISSING
    if (typeof value !== "number")
        return String(value)

    var text = String(spec === undefined || spec === null ? "" : spec).trim()
    var fixed = /^\.(\d+)([dfse%])?$/.exec(text)
    if (fixed) {
        var places = parseInt(fixed[1])
        var kind = fixed[2] === undefined ? "f" : fixed[2]
        if (kind === "d")
            return String(Math.round(value))
        if (kind === "e")
            return value.toExponential(places)
        if (kind === "s")
            return String(value)
        return (kind === "%" ? value * 100 : value).toFixed(places)
    }
    var bare = /^([dse%])$/.exec(text)
    if (bare) {
        if (bare[1] === "d")
            return String(Math.round(value))
        if (bare[1] === "%")
            return String(Math.round(value * 100))
        if (bare[1] === "e")
            return value.toExponential()
    }
    // No spec: a whole number keeps its units to itself.
    return Number.isInteger(value) ? String(value) : String(value)
}

// A template: `"{load:.0f}% · {temp:.0f}°C"`.
function fill(template, values) {
    if (typeof template !== "string")
        return ""
    return template.replace(PLACEHOLDER, function (whole, path, spec) {
        return one(spec, lookup(values, path))
    })
}

// What a `value:` names: a reading, by name or path, or a number written out.
function reading(spec, values) {
    if (typeof spec === "number")
        return spec
    var found = lookup(values, spec)
    if (typeof found === "number")
        return found
    if (typeof found === "string") {
        var parsed = parseFloat(found)
        return isNaN(parsed) ? undefined : parsed
    }
    return undefined
}

// The samples a chart draws: the last `span` of the value it names.
function series(spec, samples) {
    var name = String(spec === undefined ? "" : spec).split(".")[0]
    var all = (samples && samples[name]) ? samples[name] : []
    var span = spec && spec > 0 ? spec : all.length
    return all.slice(Math.max(0, all.length - span))
}

// How full a bar or a gauge is, given its floor and ceiling.
function fraction(value, minimum, maximum) {
    if (value === undefined || value === null)
        return 0
    var low = typeof minimum === "number" ? minimum : 0
    var high = typeof maximum === "number" ? maximum : 100
    if (high === low)
        return 0
    return Math.max(0, Math.min(1, (value - low) / (high - low)))
}

// A role, as a colour. `ink` carries the widget's own palette and the three
// indicator tones, so a definition says `accent` or `bad` and never a hex.
function colour(role, ink) {
    if (!ink)
        return "white"
    switch (role) {
    case "muted": return ink.muted
    case "accent": return ink.accent
    case "accentText": return ink.accentText
    case "raised": return ink.raised
    case "dim": return ink.dim
    case "ground": return ink.ground
    case "border": return ink.border
    case "good": return ink.good
    case "warn": return ink.warn
    case "bad": return ink.bad
    }
    return ink.text
}
