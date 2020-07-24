---
title: Intelligent Alert system for HEP experiments
layout: post
categories: [GSOC, Intelligent Alert System, golang]
description: "Google Summer of Code 2020"
---

<img src="/assets/img/cern/gsoc_cern.png"/>
<h3>Will Write some information about the project</h3>

Quick Links :-

<a target="_blank" href="https://github.com/dmwm/CMSMonitoring">CMSMonitoring</a> <br>
<a target="_blank" href="https://docs.google.com/document/d/1ATRWZLzsexHgdx73_PFwNGIUrUaudskSJ-FYnyZOHHw/edit?usp=sharing">GSOC Progress Report</a>

* hello
{:toc}

## Problem

The growth of distributed services introduces a challenge to properly monitor their status and reduce operational costs.”

Tools in use :-
ElasticSearch
Kafka
Grafana
Prometheus
AlertManager
VictoriaMetrics
Custom Solutions like GGUS, SSB system etc.

CMS infrastructure can produce significant amount of data on :-
various anomalies
intermittent problems
outages
scheduled maintenance.

So, in short our operational teams deal with a large amount of alert notifications and tickets !

## Solution

An intelligent Alert Management System

Aim

- detect
- analyse
- spot anomalies
- silence false alerts
- automate operation procedures

The system’s abilities include, but are not limited to :-
Consuming tickets from various ticketing systems. (GGUS & SSB have been implemented). Being modular architecture, there’s always a scope to add more services in future.
Extracting alerts, relevant to the specific CMS services which gets affected by such interventions
Intelligently grouping and ranking those alerts.
Silencing false alerts.
Making them visible in our monitoring tools (Grafana, Slack, Karma etc.).

## Proposed Architecture

<img src="/assets/img/cern/full_arch2.png" alt="drawing" width="1200"/>

Components Developed

- Parser
- Alerting Module
- Alerting Service
- Intelligence Module
- Alert CLI Tool

Tools

- Grafana
- Prometheus
- AlertManager
- Slack
- Karma

## Parsers

### GGUS

<img src="/assets/img/cern/ggus_parser.png" alt="drawing" width="300"/>
GGUS Ticketing System outputs 
data either in XML or CSV.
Developed Parser capable of parsing 
both formats.
ggus_parser has  two components :-
parse - parses the XML or CSV data
convert - converts the parsed data
into JSON format and saves it to disk.
XML/CSV formats are configurable

GGUS Ticket (csv)

Ticket-ID,Type,VO,Site,Priority,Resp. Unit,Status,Last Update,Subject,Scope
147196,USER,cms,FZK-LCG2,urgent,NGI_DE,assigned,2020-07-14,FZK-LCG2: issues on data access,WLCG

Which is Parsed and Converted into …..

GGUS Parsed Ticket (JSON)

```json
{
  "TicketID": 147196,
  "Type": "USER",
  "VO": "cms",
  "Site": "FZK-LCG2",
  "Priority": "urgent",
  "ResponsibleUnit": "NGI_DE",
  "Status": "assigned",
  "LastUpdate": "1590670920",
  "Subject": "FZK-LCG2: issues on data access",
  "Scope": "WLCG"
}
```

### SSB

<img src="/assets/img/cern/monit.png" alt="drawing" width="300"/>
What about SSB Ticketing System ?

There was no need of parser for SSB Ticketing System.
monit tool was developed by CMS.
Query InfluxDB/ES data sources in MONIT via Grafana proxy
SSB alerts in JSON format is given on standard output.
We piped stdout to .json file and saved to disk.

Ref :- <a target="_blank" href="https://github.com/dmwm/CMSMonitoring/blob/master/src/go/MONIT/monit.go">monit</a>

**MONIT Query**

`monit -query=$query -dbname=$dbname -token=$token -dbid=$dbid > ssb_data.json`

## Alerting Module

<img src="/assets/img/cern/alert_mod.png" alt="drawing" width="400"/>
Components Developed
- fetch
- convert
- post
- get
- delete

<span style="color:red">\*now onwards we will call each ticket from GGUS/SSB as an alert</span>

- fetch
  - fetches saved JSON GGUS or SSB data from the disk (ggus_parser or monit)
  - maintains a hashmap for seen alerts
  - map[alert_name] = alert
- convert
  - fetched alerts are input here
  - gets converted to JSON data which AlertManager API understands
- post
  - converted JSON data which contains GGUS/SSB alerts is pushed to AlertManager.
- get
  - Few GGUS/SSB alerts do not have Ending Time, hence open ending.
  - We fetch GGUS/SSB alerts from AlertManager
  - Check with HashMap (which updates), if an alert is resolved or not.
  - Bundle all resolved alerts
- delete
  - All resolved alerts will now have End Time == time.Now()
  - All open ending alerts in AlertManager get new EndTime,
  - thus get deleted

## Alerting Service

<img src="/assets/img/cern/alert_srv.png" alt="drawing" width="400"/>
- Parser fetches data and saves to disk
- Alerting module gets fetched data as input, converts it and pushes to AM.
- This whole process is bundled as a Linux Service with three commands :-
    - start
    - stop
    - status

Image beside shows an alerting service architecture

Components

- parser / monit
- \*.alerting module

Alerting service -> A linux service running both of these logics at a regular interval in the background.

Configuration

- AlertManager URL
- Time Interval for the service
- HTTP Timeout
- Verbosity Level
- GGUS
  - GGUS Format
  - VO
- SSB
  - Query
  - Token

## AlertManager - one place for all alerts

<img src="/assets/img/cern/am.png" alt="drawing" width="300"/>
Alerting services which has been developed push GGUS & SSB alerts to AM at defined time interval.
Grafana & Prometheus push their alerts to AM as well.
Karma Dashboard fetches all alerts from AM, and displays in better format.
Slack channels are populated when an alert is fired.
AM, Slack and Karma give all required info for alerts to our Admins.

## Use of Slack & Karma

Slack
Slack has defined channels for particular service alerts.
Users are notified about fired alerts.
AlertManager bots are at work.

Karma
A dashboard which pulls all alerts from AM.
Availability of multi grids arrangement based on filters.
Bundling similar alerts
Concise and better view than AM.
Wrote Dockerfile and Kubernetes config files.

## Intelligence Module

<img src="/assets/img/cern/int/int_mod.jpg" alt="drawing" width="400"/>
A data pipeline.
Components independent of each other.
One component receives the data, adds its logic and forwards the processed data to other component.

Why data pipeline ?
Low coupling
Freedom of adding or removing components on demand.
Power of concurrency

What it does ?
Assigning proper severity levels to SSB/GGUS alerts which helps operators to understand the criticality of the infrastructure.
Ex. If Number of Alerts with severity=”urgent” > some threshold, then the infrastructure is in critical situation.
Annotating Grafana Dashboards when Network or Database interventions.

Scope for additional features include, but are not limited to :-
Predicting type of alerts and grouping similar alerts with the help of Machine Learning.
Adds applicable tutorial/instructions doc to alert, on following which an operator can solve the issue.

Components

- Fetch Alerts
- Preprocessing
- Keyword Matching
- Add Annotations
- Machine Learning
- Push Alert
- Silence Alert

Tools

- AlertManager
- Grafana

**Fetch Alerts**
<img src="/assets/img/cern/int/fetch_alerts.jpg" alt="drawing" width="250"/>

- Fetches all alerts from AlertManager
- Bundles them and put them on a channel.
- Channel (Analogy) - baggage belt at Airports. You put data into it, data will be picked up when required by other party.

**Preprocessing**
<img src="/assets/img/cern/int/preprocessing.jpg" alt="drawing" width="450"/>

- Filtering based on configuration.
- Only filtered alerts are forwarded.
- Here we also manage one map for keeping track of active silenced alerts to avoid redundant silences.
- If an alert is already silenced that means it has been processed by the intelligence module before.

**Keyword Matching**
<img src="/assets/img/cern/int/keyword_matching.png" alt="drawing" width="350"/>

- Analysis of Alerts showed us repetitive use of a few important keywords.
- These keywords help in assigning severity levels.
- We search for these keywords in alerts, if found we assign severity level mapped to that keyword.

**Add Annotations**
<img src="/assets/img/cern/int/add_annotations.jpg" alt="drawing" width="350"/>

- Grafana has dashboards which shows running services’ metrics in the form of graphs.
- Grafana has add Annotation feature.
- SSB alert mentioning intervention in network / DB affects these services.
- We push such interventions info in the form of annotations into Grafana dashboards.

**Machine Learning**

**Push Alert**
<img src="/assets/img/cern/int/push_alert.jpg" alt="drawing" width="400"/>

- Alerts with modified information are pushed to AlertManager
- Incoming alerts are then forwarded to Silence Alert.

**Silence Alert**
<img src="/assets/img/cern/int/silence_alert.jpg" alt="drawing" width="250"/>

- Alerts which get modified and pushed to AlertManager get copied.
- Older alert is redundant
- We silence the older one for the duration of its lifetime.

## Alert CLI Tool

- Gives a nice and clean CLI interface for getting alerts, their details printed on the terminal itself either in tabular form or JSON format.
- Convenient option for operators who prefer command line
- Comes with several options such as :-
  - service, severity, tag - Filters
  - sort - Sorting
  - details - For detailed information of an alert
  - json - information in JSON format

## Future Work

- Evaluation of ElastAlert for setting alerts on ElasticSearch and integration of the same in this project.
- Service which takes configuration for operator’s actions and pushes to AM so that it matches alerts with the actions.
- Use of Machine Learning in intelligence module which will predict it’s severity info, priority and type.
- Deployment of finalized project to k8s infrastructure.

## Tools Used

- Programming Language

  <img style="margin-left:0px;" src="https://img.icons8.com/color/48/000000/golang.png"/>

- Editor

    <div style="display:flex;">
    <img style="margin-left:0px; margin-right:10px;"  src="https://upload.wikimedia.org/wikipedia/commons/9/9f/Vimlogo.svg" width="48px"/>
    <img style="margin-left:0px; margin-right:10px;"  src="https://img.icons8.com/fluent/48/000000/visual-studio-code-2019.png"/>
    </div>

- Helper Tools

    <div style="display:flex;">
    <img style="margin-left:0px; margin-right:10px;"  src="https://img.icons8.com/color/48/000000/github.png"/>
    <img style="margin-left:0px; margin-right:10px;"  src="https://img.icons8.com/color/48/000000/git.png"/>
    <img style="margin-left:0px; margin-right:10px;"  src="http://networkbit.ch/wp-content/uploads/2018/12/golang_lint-300x112.png" width="130px"/>
    </div>
    <div style="display:flex;">
    <img style="margin-left:0px; margin-right:10px;"  src="https://img.icons8.com/color/48/000000/adobe-photoshop.png"/>
    <img style="margin-left:0px; margin-right:10px;"  src="https://img.icons8.com/color/48/000000/google-docs.png"/>
    <img style="margin-left:0px; margin-right:10px;"  src="https://img.icons8.com/color/48/000000/google-slides.png"/>
    </div>

## Acknowledgements

I am thankful to my mentors for their invaluable guidance and support throught my GSoC journey.

### Mentor details

{% for mentor in site.data.people.mentors %}
 <div class="mentor-detail" style="display:flex;  ">
<img style="margin-left:0px; margin-right:10px; border-radius: 100%; object-fit: cover;" src="{{mentor.link}}" height="{{mentor.ht}}" width="{{mentor.wt}}" />
 <a style="text-decoration:none; hover:background-color: yellow;" href="mailto:{{mentor.email}}">{{mentor.name}} <br> {{mentor.pos}}</a>
    </div>
{% endfor %}

### Contact Me
{% for mentor in site.data.people.me %}
 <div class="mentor-detail" style="display:flex; ">
<img style="margin-left:0px; margin-right:10px; border-radius: 100%; object-fit: cover;" src="{{mentor.link}}" height="{{mentor.ht}}" width="{{mentor.wt}}" />
 <a style="text-decoration:none; hover:background-color: yellow;" href="mailto:{{mentor.email}}">{{mentor.name}} <br> {{mentor.pos}}</a>
    </div>
{% endfor %}
- Feel free to send me a mail at <a href="mailto:indrarahul2018@gmail.com">indrarahul2018@gmail.com</a>
- Raise issues if any at:
  - <a target="_blank" href="https://github.com/dmwm/CMSMonitoring">CMSMonitoring</a>
