#!/usr/bin/env python

import sys
import telepot

def sendmessage(botid, destid, message, parse_mode='Markdown'):
    bot = telepot.Bot(botid)
    bot.sendMessage(destid, message, parse_mode=parse_mode)

def getids():
    sys.argv.pop(0) # remove script name
    botid = sys.argv.pop(0)
    #print 'botid', botid, sys.argv
    destid = sys.argv.pop(0)
    #print 'destid', destid, sys.argv

    return botid, destid

def main():
    botid, destid = getids()

    if sys.argv:
        message = " ".join(sys.argv)
    else:
        message = "".join(sys.stdin.readlines())
    sendmessage(botid, destid, message)

if __name__ == "__main__":
    main()
