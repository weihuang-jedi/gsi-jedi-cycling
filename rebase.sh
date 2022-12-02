!#bin/bash

#fetching remote 'feature/my_feature_branch' branch to the 'tmp' local branch 
git fetch origin dajedi2:tmp

#rebasing on local 'tmp' branch
git rebase tmp

#pushing local changes to the remote
git push origin HEAD:dajedi2

#removing temporary created 'tmp' branch
git branch -D tmp
