# Description:
#   Show open pull requests from a Github repository or organization
#
# Dependencies:
#   "githubot": "0.4.x"
#
# Configuration:
#   HUBOT_GITHUB_TOKEN
#   HUBOT_GITHUB_USER
#   HUBOT_GITHUB_API
#
# Commands:
#   hubot show [me] <user/repo> pulls [with <regular expression>] -- Shows open pull requests for that project by filtering pull request's title.
#   hubot show [me] <repo> pulls -- Show open pulls for HUBOT_GITHUB_USER/<repo>, if HUBOT_GITHUB_USER is configured
#
# Notes:
#   HUBOT_GITHUB_API allows you to set a custom URL path (for Github enterprise users)
#
#   You can further filter pull request title by providing a regular expression.
#   For example, `show me hubot pulls with awesome fix`.
#
# Author:
#   jingweno

module.exports = (robot) ->

  github  = require("githubot")(robot)
  preview = github.withOptions(apiVersion: 'squirrel-girl-preview')

  generatePullAttachment = (pull) ->
    new Promise (resolve) ->
      preview.get "#{pull.issue_url}/reactions", (reactions) ->
        thumbsupReactions = (reactions.filter (r) -> r.content == "+1")
        thumbsup = thumbsupReactions.reduce (t, s) ->
          ":+1:#{t}[#{s.user.login}]"
        , ""

        color = ""
        switch thumbsupReactions.length
          when 0
            color = "e0ffff"
          when 1
            color = "87ceeb"
          when 2
            color = "00bfff"
          else
            color = "1e90ff"

        attachment =
          color: color
          fallback: pull.title
          title: pull.title
          title_link: pull.html_url
          author_name: pull.user.login
          author_link: pull.user.html_url
          author_icon: pull.user.avatar_url
          text: pull.body
          fields: [value: thumbsup]
          mrkdwn_in: ["text","fields"]

        resolve attachment

  unless (url_api_base = process.env.HUBOT_GITHUB_API)?
    url_api_base = "https://api.github.com"

  robot.respond /show\s+(me\s+)?(.*)\s+pulls(\s+with\s+)?(.*)?/i, (msg)->
    repo = github.qualified_repo msg.match[2]
    filter_reg_exp = new RegExp(msg.match[4], "i") if msg.match[3]

    github.get "#{url_api_base}/repos/#{repo}/pulls", (pulls) ->
      if pulls.length == 0
        message = "Open中のPull Requestはありませんでした"
        msg.send message
        return

      else
        filtered_result = []
        for pull in pulls
          if filter_reg_exp && pull.title.search(filter_reg_exp) < 0
            continue
          filtered_result.push(pull)

        if filtered_result.length == 0
          message = "フィルタにマッチするOpen中のPull Requestはありませんでした"
          msg.send message
          return

        else
          message = "[#{repo}]Open中のPull Requestが#{filtered_result.length}件あります"

        tasks = (generatePullAttachment(pull) for pull in pulls)

        Promise.all(tasks).then (attachments) ->
          msg.send attachments: attachments
          msg.send message

