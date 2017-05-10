# WeeklyBot

WeeklyBot is a slack bot based on the [hubot](https://hubot.github.com/) framework, designed to make it easy for users to check updates for weekly refresh.  
This project was originally based off of [showoff](https://github.com/phillipspc/showoff).

### Usage

Available commands are:
- `coe`
- `crucible`
- `nightfall`
- `strike`
- `story`
- `raid`

### Testing it out
If you want to test out the bot before using it in a public channel, try sending it a direct message. You do not need "@bot-name" when you are messaging the bot directly, just the inputs.

### Setting up the bot in your own slack
First clone the repo locally:  
`git clone git@github.com:RuCray/destiny_weekly_update.git`

To deploy to heroku, `cd` into the newly created folder then follow these steps:

- Install [heroku toolbelt](https://toolbelt.heroku.com/) if you haven't already.
- Activate the Hubot service on your ["Team Services"](http://my.slack.com/services/new/hubot) page inside Slack.
- `heroku create my-new-slackbot`
- `heroku addons:create rediscloud:30`
- `git push heroku master`

You'll need to add the following [config variables](https://devcenter.heroku.com/articles/config-vars) (easiest way is through the Heroku Dashboard). [Get a Bungie API key](https://www.bungie.net/en/Application)

`HEROKU_URL=https://my-new-slackbot.herokuapp.com`  
`HUBOT_SLACK_TOKEN=your-slack-token-here`  
`BUNGIE_API_KEY=your-bungie-key-here`
