#!/usr/bin/env python3

from urllib.request import urlopen
import re
import sys
from bs4 import BeautifulSoup

release=sys.argv[1]
# can be: service-projects service-client-projects library-projects
section=sys.argv[2]

html = urlopen('https://releases.openstack.org/'+ release +'/index.html')
bsObj = BeautifulSoup(html, 'lxml')

service_client_projects = bsObj.find(
    'div',
    {
        'class': 'section',
        'id': section,
    }
).findAll('div', {'class': 'section'})

for project in service_client_projects:
    versions = [x.td.get_text() for x in project.tbody.findAll('tr')]
    ver = project.tbody.tr.td
    print(
        project['id'],
        versions[-1],
        versions[0],
        ver.a['href']
    )
