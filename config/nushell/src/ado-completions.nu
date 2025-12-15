# Necessary environment variables
# $env.ADO_ORGANIZATION = ''  # (1) go to https://dev.azure.com and copy the name of your organization from the left side bar.
# $env.ADO_PROJECT = ''       # (2) inside that organization copy the project name
# $env.ADO_TOKEN = ''         # (3) go to https://dev.azure.com/ADO_ORGANIZATION/_usersSettings/tokens and create a new token
# $env.ADO_TEAM = ''          # (4) `az devops team list -ojson | from json | select name id description | explore` to see teams and copy desired uuid
# $env.ADO_REPO = ''          # (4) `az repos list | from json | select name id` to see repos and copy desired uuid

use git-completions.nu "nu-complete git checkout"

export def "nu-complete semmantic-message" [] {
    # https://gist.github.com/joshbuchea/6f47e86d2510bce28f8e7f42ae84c716
    [
        [value    description];
        [build    "new feature for the user, not a new feature for build script"]
        [chore    "updating grunt tasks etc; no production code change"]
        [ci       "ci"]
        [docs     "changes to the documentation"]
        [feat     "new feature for the user, not a new feature for build script"]
        [fix      "bug fix for the user, not a fix to a build script"]
        [perf     "performance"]
        [refactor "refactoring production code, eg. renaming a variable"]
        [style    "formatting, missing semi colons, etc; no production code change"]
        [test     "adding missing tests, refactoring tests; no production code change"]
    ]
}

export module ado {

    def "nu-complete my-tasks" [] {
        (list my tasks)
        | rename -c {id: value,  title: description} | select value description
    }

    def "nu-complete my-stories" [] {
        (list my stories)
        | rename -c {id: value,  title: description} | select value description
    }


    const dbfile = ('~/.git-ado.json' | path expand )

    export def read_git_ado_db [] {
        if ($dbfile | path exists) {
            open $dbfile
        } else {
            []
        }
    }
    export def write_git_ado_db [db] {
        $db | to json | save -f $dbfile
    }

    # review a pr on a separate folder
    export def "pr review" [ branch: string ] {
        git fetch --all | ignore
        let startingat = $"origin/($branch)"
        let path = $branch | str replace "/" "--" | str replace " " "-"
        print $"(ansi pb)git worktree add -B ($branch) ($path) ($startingat)(ansi reset)"
        git worktree add -B $branch ('..' | path join $path) $startingat
    }

    # git worktree add - convenience wrapper
    export def "worktree add" [
        branch: string # branch to create or checkout, e.g. cesc/1234-my-description
        path: path # checkout location
        --startingat(-@): string@"nu-complete git checkout"  # create a new branch starting at <commit-ish> e.g. master,
        # custom stuff
        --story(-s): int@"nu-complete my-stories"  # story number
        --task(-t): int@"nu-complete my-tasks"   # task number
        --no-pr # don't create pr
    ] {
        let branch_name = if ($branch | is-empty) { (git rev-parse --abbrev-ref HEAD) } else { $branch }

        let db = read_git_ado_db

        mut data = {
            name: $branch_name
            story: (if $story == null { 0 } else { $story })
            task: (if $task == null { 0 } else { $task })
            pr: 0
        }


        let repo_name = pwd | path basename | str replace ".git" ""
        # make sure path has no slashes coming from branch name
        # let branch_folder = $branch | str replace -a -r `[\\/]` "-"
        # let path = (".." | path join $"($repo_name)-($branch_folder)")

        git fetch --all
        if ($startingat | is-empty) {
            print $"(ansi pb)git worktree add -B ($branch) ($path)(ansi reset)"
            git worktree add -B $branch $path
        } else {
            print $"(ansi pb)git worktree add -B ($branch) ($path) ($startingat)(ansi reset)"
            git worktree add -B $branch $path $startingat
        }

        write_git_ado_db ($db | append $data)
        if not $no_pr {
            cd $path
            let title = $branch
            let pr = pr new $"🏗️: ($title)" --draft
            $data.pr = $pr.id
            write_git_ado_db ($db | append $data)
        }
    }

    export def --wrapped "commit" [
        type: string@"nu-complete semmantic-message"
        title: string
        --scope(-s): string  # contextual information
        --breaking-changes(-b)
        ...rest
    ] {

    let scope = if ($scope | is-empty) { "" } else { $"\(($scope)\)" }
        let breaking_change = if $breaking_changes { "!" } else { "" }
        let current_branch = (git rev-parse --abbrev-ref HEAD)
        let db = read_git_ado_db

        mut links = []
        let story = ( $db | where name == $current_branch | get story.0 )
        let task = ( $db | where name == $current_branch | get task.0 )
        if $story != 0 { $links = ($links | append [-m $"story #($story)"]) }
        if $task != 0 { $links = ($links | append [-m $"task #($task)"]) }

        let pr = ( $db | where name == $current_branch | get pr.0 )
        let title = [ -m $"($type)($scope)($breaking_change): ($title) - PR ($pr)" ]

        ^git commit ...$title ...$links ...$rest
    }


    export def "pr new" [
        title?: string
        --target-branch (-t): string = 'master'
        --draft
    ] {
        git push
        let main_or_master = git rev-parse --abbrev-ref origin/HEAD
        let description = (git log --format=%B $"(git merge-base HEAD $main_or_master)..HEAD")
        let title = if ($title | is-empty) { ( git log --format=%B -n 1 HEAD ) | lines | first } else { $title }
        # [ "**Problem:** " "" "**Solution:** " "" "**Notes:** " ] | to text | save -f $description

        nvim $description

        let db = read_git_ado_db
        let current_branch = (git rev-parse --abbrev-ref HEAD)
        # let work_items = ([
        #     ( $db | where name == $current_branch | get story.0 )
        #     ( $db | where name == $current_branch | get task.0 )
        # ] | where { $in != 0})

        mut args = []
        if $draft { $args = ($args | append '--draft') }
        ( ^az repos pr create --open --delete-source-branch
            --description ...($description | open | lines)
            --auto-complete -t $target_branch
            # --work-items ...($work_items)
            --title $title
            ...$args
            -o json
        )
        | from json
    }

    export def "pr status" [
        pr_id: number@"nu-complete pr-id"
        --pending(-p)  # list only not yet approved policies
        --with-policy-id
    ] {
        let status = (
            az repos pr policy list --id $pr_id -ojson | from json
            | where {$in.configuration.isBlocking and $in.configuration.isEnabled}
            | select status context.isExpired? configuration.settings.displayName? configuration.type.displayName evaluationId
            | rename status expired            title                               type                           policy-id
            | sort-by status expired
        )
        let status = if $with_policy_id { $status } else { $status | reject policy-id }
        if $pending { $status | where status != approved } else { $status }
    }

    # Get azure devops machines having a certain capability
    export def "list machines-usercapabilities" [ has_capability: string = 'Python311' ] {
        (  az pipelines agent list
            --pool-id 1 --include-capabilities -o json
            --query $"[?userCapabilities.($has_capability)!=null].{capabilities: userCapabilities, name: name}"
        ) | from json
    }

    # Get azure devops machines
    export def "list machines" [ ] {
        (  az pipelines agent list
            --pool-id 1 --include-capabilities -o json
            --query "[*]"
        ) | from json
    }

    # Yield remote branches like `origin/main`, `upstream/feature-a`
    def "nu-complete git remote branches" [] {
      ^git branch --no-color -r | lines | parse -r '^\*?(\s*|\s*\S* -> )(?P<branch>\S*$)' | get branch | uniq | parse "{remote}/{branch_name}" | get branch_name
    }

    def "nu-complete pipeline-definitions" [] { [
        [value description];
        [42    pr]
        [80    installer]
    ] }


    export def "queue build" [
      branch: string@"nu-complete git remote branches"
      definition_id: int@"nu-complete pipeline-definitions" = 42
    ] {
        az pipelines build queue --open --branch (git rev-parse --abbrev-ref HEAD) --definition-id $definition_id
    }

    export def "download artifact" [ build_id: int ] {
        az pipelines runs artifact download --artifact-name Installer --path ~/Downloads --run-id $build_id
    }


    # NOTE: https://learn.microsoft.com/en-us/azure/devops/boards/queries/wiql-syntax?view=azure-devops#where-clause
    # active items ['Closed' 'Obsolete' Review 'Info Needed' Implemented] }

    def "board query" [wiql: string] {
        let table = az boards query --output table --wiql $wiql -o json
        if ($table | is-empty) {
            print $"(ansi pb)Table empty(ansi reset)"
            return
        }
        $table
        | from json
        | select fields | flatten
        | rename --column { System.State: state,
                            System.Id: id,
                            System.WorkItemType: type,
                            System.IterationPath: iteration_path,
                            System.Title: title
                            System.ChangedDate: canged_date
                            System.CreatedDate: created_date }
        | sort-by state created_date title
        | move id --first
        | move state --after id
        | move type --after state
        | move title --after type

    }

    const select_from_workitems = "SELECT [System.Id], [System.WorkItemType], [System.Title], [System.State], [System.IterationPath], [System.CreatedDate], [system.ChangedDate] FROM workitems"

    export def "list bugs" [] {
        let wiql = [ $select_from_workitems
            "WHERE [System.WorkItemType] = 'Bug' AND [system.state] NOT IN ('Closed', 'Obsolete')"
            "ORDER BY [Microsoft.VSTS.Common.Priority], [System.ChangedDate] ASC" ] | str join ' '
        board query $wiql
    }

    export def "list my stories" [] {
        let wiql = [ $select_from_workitems
            "WHERE [system.assignedto] = @me AND [System.WorkItemType] <> 'Task' AND [system.state] NOT IN ('Closed', 'Obsolete')"
            "ORDER BY [Microsoft.VSTS.Common.Priority], [System.ChangedDate] ASC" ] | str join ' '
        board query $wiql
    }

    export def "list my tasks" [] {
        let wiql = [ $select_from_workitems
            "WHERE [system.assignedto] = @me AND [System.WorkItemType] = 'Task' AND [system.state] NOT IN ('Closed', 'Obsolete')"
            " ORDER BY [Microsoft.VSTS.Common.Priority], [System.ChangedDate] ASC" ] | str join ' '
        board query $wiql
    }

    export def "list assigned-to-me" [] {
        let wiql = [ $select_from_workitems
            "WHERE [system.assignedto] = @me AND [system.state] NOT IN ('Closed', 'Obsolete')"
            "ORDER BY [Microsoft.VSTS.Common.Priority], [System.ChangedDate] ASC"] | str join " "
        board query $wiql
    }

    export def "list created-by-me" [] {
        let wiql = [ $select_from_workitems
            "WHERE [System.CreatedBy] = @me AND [system.state]  NOT IN ('Closed', 'Obsolete')"
            "ORDER BY [System.ChangedDate] ASC" ] | str join ' '
        board query $wiql
    }

    export def "list following" [] {
        let wiql = [ $select_from_workitems
            "WHERE [System.ID] IN (@Follows) AND [system.state]  NOT IN ('Closed', 'Obsolete')"
            "ORDER BY [System.ChangedDate] ASC" ] | str join ' '
        board query $wiql
    }

    # list my pull requests
    export def "list prs" [] {
        let my_query = "[].{title: title, createdby: createdBy.displayName, reviewers: reviewers, status: status, repo: repository.name, id: pullRequestId, draft: isDraft }"
        let prs = az repos pr list -ojson --query $my_query | from json | select id status createdby reviewers title draft
        $prs | insert ci-status {
            pr status $in.id
            | select status title type | sort-by type status
            | update cells -c [status] { $in | str replace approved ✅| str replace running 👟| str replace queued ⏳| str replace rejected ❌ }
        }
    }

    # list my pull requests
    export def "list my prs" [--draft] {
        let my_query = "[].{title: title, createdby: createdBy.displayName, reviewers: reviewers, status: status, repo: repository.name, id: pullRequestId, draft: isDraft }"
        let prs = az repos pr list -ojson --query $my_query | from json | where createdby =~ "Francesc" | select id status title draft
        let prs = if $draft { $prs | where draft } else { $prs | where not draft }
        $prs | insert ci-status {
            pr status $in.id
            | select status title type | sort-by type status
            | update cells -c [status] { $in | str replace approved ✅| str replace running 👟| str replace queued ⏳| str replace rejected ❌ }
        }
    }

    def "nu-complete pr-id" [] { (list my prs) | rename -c {id: value,  title: description} }

    export def "pr rejected-or-expired-policies" [ pr_id: number@"nu-complete pr-id" ] {
        ( az repos pr policy list --id $pr_id -ojson | from json
            | where {$in.configuration.isBlocking and $in.configuration.isEnabled}
            | select evaluationId configuration.type.displayName configuration.settings.displayName? status context.isExpired? context.buildId?
            | rename id           type                           title                               status expired            build-id
            | where type == Build
            | where status == rejected or expired == true
        )
    }

    # trigger ci for PR
    export def "pr ci re-queue" [ pr_id: number@"nu-complete pr-id" ] {
        ( pr rejected-or-expired-policies $pr_id | par-each {
            print $"(ansi pb)\tRe-queueing: ($in.title), previous build ($in.build-id) status=($in.status) expired=($in.expired)(ansi reset)"
            ( az repos pr policy queue --id $pr_id -e $in.id -ojson | from json
                | select status configuration.settings.displayName? configuration.type.displayName evaluationId
                | rename status title                               type                           id)
        })
    }

    export def "pr ci watch" [ pr_id: number@"nu-complete pr-id" ] {
        let pr = (az repos pr show --id  $pr_id | from json )
        let pr_title = $"PR ($pr_id) - ($pr | get title)"
        print $"(ansi pb)Watching(ansi reset) ($pr_title)"
        loop {
            if (((az repos pr show --id  $pr_id | from json ) | get status) == completed) {
                return $"($pr_title) (ansi lgi)completed(ansi reset)"
            }
            let result = pr ci re-queue $pr_id
            if (not ($result | is-empty)) { print $result }
            sleep 60sec
        }
    }

    export def "pr show-commits" [ pr_id: number@"nu-complete pr-id" ] {
        ( az devops invoke
            --area git
            --resource pullRequestCommits
            --route-parameters project=($env.ADO_PROJECT) repositoryId=($env.ADO_REPO) pullRequestId=($pr_id)
            --http-method GET
            --output json )
        | from json
        | get value
        | select author.name comment commitId
    }

    export def "list wikis" [] {
        ( az devops invoke --area wiki --resource wikis --route-parameters project=($env.ADO_PROJECT)
            | from json
            | get value
            | select mappedPath name type remoteUrl versions )
    }

    def "nu-complete my-workitems" [] {
        [ | | { list my stories }
          | | { list my tasks }
          | | { list assigned-to-me }
          | | { list created-by-me }
          | | { list following } ]
          | par-each { do $in }
          | flatten
          | rename -c {id: value,  title: description} | select value description
    }

    export def "open workitems" [ ...workitems: int@"nu-complete my-workitems" ] {
        if ($in | is-empty) {
            $workitems | each {start $"https://($env.ADO_ORGANIZATION).visualstudio.com/($env.ADO_PROJECT)/_workitems/edit/($in)" }
        } else {
            $in | get id | each { start $"https://($env.ADO_ORGANIZATION).visualstudio.com/($env.ADO_PROJECT)/_workitems/edit/($in)" }
        }
    }
}

export def "my stories" [] {
    ado list my stories | ado open workitems
    ado list my tasks | ado open workitems
}

