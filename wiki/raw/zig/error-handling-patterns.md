# Error Handling in Zig with try, catch, and if

> Source: https://www.luisllamas.es/en/zig-error-handling-catch-try/
> Collected: 2026-10-05
> Published: Unknown

# Error Handling in Zig with try, catch, and if

The catch and try operators are _**the basic tools for consuming and propagating errors in Zig**_. In the previous article, we saw that a function can return an error union (`!T`): it can contain the data we want or an error.

The Zig compiler is strict: **it won’t let you use the value without first checking if it’s an error**. You have to “handle the package.”

To do this, Zig gives us three main tools: `catch`, `try`, and `if` with capture. Let’s see how to use them to write robust and linear code.

## The `catch` operator

`catch` is the most direct way to handle an error. It reads almost like English: _“Try to do this, and if it fails, **catch** the error and do this instead.”_

It is mainly used when we want to recover from the failure by providing a **default value**.

For this to work, the data type on the right (the 0) must match the type the function promised to return (`u32`).

### `catch` with blocks

Sometimes, recovery is more complex than simply returning a fixed number. Perhaps we need to log the error before deciding what to do. In that case, `catch` accepts a code block.

The key part is `|err|`. Just like in `for` loops, we can capture the actual error to inspect it (for example, in a `switch`) and make different decisions depending on the type of failure.

## The `try` keyword

In most cases, when a function fails, we don’t know how to fix it “on the spot.” The only sensible thing we can do is **return the error to the caller** so they can decide.

In languages like Go, this creates the famous _boilerplate_:

In Zig, we have the try keyword.

**`try` is NOT a `try-catch` block** like in Java or JavaScript. It is a prefix operator meaning: _“If this is an error, `return` that error right now. If not, give me the clean value.”_

This keeps the code flat and readable. You can chain operations that may fail without nesting multiple `if` statements.

## `if` with error capture

Sometimes we don’t want to return the error (`try`) or use a default value (`catch`). We want to branch the logic: _“If it goes well, do A; if it goes wrong, do B.”_

For this, we use `if` on the returned value, capturing the error in the `else`.

This structure is identical to the one we saw with Optionals (`if (opt) |v| else ...`). It’s Zig’s consistent way of handling “uncertain results.”

## `catch unreachable`

There are situations where, theoretically, a function returns an error (because its signature says so), but we know **with absolute certainty** that it won’t fail in this context.

If we ignore the error, the code won’t compile. If we use `try`, we have to change our `main` or current function’s signature.

The solution is to tell the compiler: _“If this fails, it’s an impossible bug. Crash the program.”_

If the function fails, `unreachable` is reached: in Debug and ReleaseSafe it produces a **panic**, while ReleaseFast and ReleaseSmall don’t necessarily retain that check. Only use it when the error reveals a broken precondition or a program bug.

## Tool comparison

Tool

Syntax

Meaning

Typical Use

**Catch Default**

`func() catch 0`

“If it fails, use 0”

Default values, simple recovery.

**Try**

`try func()`

“If it fails, return the error”

Propagating errors upward.

**If Error**

\`if (func())

v

else

**Unreachable**

`func() catch unreachable`

“Failing here breaks a precondition”

Checked invariants.

## Putting it together: `defer`, `errdefer`, and errors

Now that we know `defer` and error handling, we can combine them using `errdefer`.

`errdefer` works just like `defer`, but **only executes if the function returns an error**.

It is used to clean up resources acquired during a construction that doesn’t complete.
