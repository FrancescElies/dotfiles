export def ask_yes_no [question: string] {
    return (
        match (input $"(ansi purple_bold)($question)(ansi reset) [y/n]") {
          "y" | "yes" | "Y" => true,
          _ => false,
        }
    )
}
