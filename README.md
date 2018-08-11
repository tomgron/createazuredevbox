# createazuredevbox
Set of scripts to create new Azure VM with all developer tools installed. Idea is to use vanilla windows images from normal Azure SKUs

Idea is to have kind of "immutable" devbox, where all user needs to do is to kick off an installation script (e.g. at evening) and once it has done all installations, there is a fresh copy of DevBox waiting (e.g. in the morning).

Ideally this would not only setup the environment and tools but also would download all necessary sources locally to get started immediately with development (e.g. with Github/VSTS PATs or some other tokens) and would setup Git and version control, all work items tracking etc. so that user doesn't have to do anything but to jump in and start coding.

Also there could be some kind of options as I personnally work with different teams so the tooling might be a bit different depending on project that I'm working. Also, the built devbox should conform to the workflow I'm using - github, vsts or some local version control