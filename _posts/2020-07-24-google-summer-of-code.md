---
main_title: GSOC'20 with CERN-HSF !
title: Intelligent Alert system for HEP experiments
layout: post
---

<img src="/assets/img/cern/gsoc_cern.png"/>
The project aims to develop an intelligent and reliable monitoring system for large distributed services to monitor their status and reduce operational costs. The distributed computing infrastructure is the backbone of all computing activities of the CMS experiments at CERN. These distributed services include central services for authentication, workload management, data management, databases, etc.

Very large amounts of information are produced from this infrastructure. These include various anomalies, issues, outages, and those involving scheduled maintenance. The sheer volume and variety of information make it too large to be handled by the operational team. Hence we aim to build an intelligent system that will detect, analyze and predict the abnormal behaviors of the infrastructure.

Quick Links :-

<div class="lnk" style="display:flex;">
{% for l in site.data.social.links %}
<div><a style="margin-right:10px; text-decoration:none;" target="_blank" href="{{l.link}}">{{l.name}}</a></div>
{% endfor %}
</div>

* hello
{:toc}

## Problem

"The growth of distributed services introduces a challenge to properly monitor their status and reduce operational costs.”

The current monitoring system makes use of following tools :-
- ElasticSearch
- Kafka
- Grafana
- Prometheus
- AlertManager
- VictoriaMetrics
- Custom Solutions like GGUS, SSB system etc.

CMS infrastructure can produce significant amount of data on :-
- various anomalies
- intermittent problems
- outages
- scheduled maintenance.

The operational teams deal with a large amount of alert notifications and tickets and generally they face difficulties in handling them manually. 

So, in short we need to automate the mundane process which allows op-teams to focus more on the finding solution for the source of alerts rather than searching, filtering and collecting the alerts and tickets.

## Solution
We propose an intelligent alert management system for the aforementioned problem.

Aims

- detect tickets
- analyse tickets
- spot anomalies in tickets (if any)
- silence false alerts
- automate operation procedures

The system’s abilities include, but are not limited to :-
- Consuming tickets from various ticketing systems. (GGUS & SSB have been implemented).But being a modular architecture, there’s always a scope to add more services in future.
- Extracting alerts which are relevant to the specific CMS services which gets affected by such interventions.
- Intelligently grouping and ranking of the alerts.
- Silencing false alerts from services which starts bombarding the system when a node goes down. So instead of logging multiple alerts from the services running on that node. We generate one single alert annotating that a specific node is down.
- Making them visible in the monitoring tools such as Grafana, Slack, Karma etc.

## Proposed Architecture

<div style="display: flex; flex-direction: column; align-items: center;">
<img src="/assets/img/cern/full_arch2.png" alt="drawing" width="1200"/>
<span>Full Architecture</span>
</div>

The above diagram depicts the proposed architecture of the Intelligent Alert Management System.

The components which I developed are :-
- Parser
- Alerting Module
- Alerting Service
- Intelligence Module
- Alert CLI Tool

Third-party tools being used are :-

- Grafana
- Prometheus
- AlertManager
- Slack
- Karma

Each developed components are the building blocks of the intelligent system. Let us discuss their implementation, features one by one.

## Parsers

AlertManager is an extensive tool for storing alerts from various sources. Prometheus, Grafana are the two most supported tools for AlertManager where you can simply define alert rules and then you are good to go. Ticketing systems such as GGUS, SSB have their own dedicated platform for issueing tickets. These tickets give an insight to the operational teams to make important decisions when outages happen which means we would want them in the AlertManager. There were no solutions than using AlertManager API endpoints which give access to CRUD operations.

### GGUS

<div style="display: flex; flex-direction: column; align-items: center;">
<img src="/assets/img/cern/ggus_parser.png" alt="drawing" width="300"/>
<span>GGUS parser diagram</span>
</div>

GGUS Ticketing System web platform outputs data either in XML or CSV formats but Alertmanager requires data to be in specific JSON format. Thus, we developed a parser which is capable of parsing both formats which is configurable. 

ggus_parser has two components :-
- parse - parses the XML or CSV data from the GGUS Ticketing System web platform
- convert - converts the parsed data into JSON format and saves it to the disk.

Let's see an example 

*GGUS Ticket (csv)*
```CSV
Ticket-ID,Type,VO,Site,Priority,Resp. Unit,Status,Last Update,Subject,Scope
147196,USER,cms,FZK-LCG2,urgent,NGI_DE,assigned,2020-07-14,FZK-LCG2: issues on data access,WLCG
```
Above is a ticket in CSV format which is parsed and converted into...

*GGUS Parsed Ticket (JSON)*

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

<div style="display: flex; flex-direction: column; align-items: center;">
<img src="/assets/img/cern/monit.png" alt="drawing" width="300"/>
<span>SSB parser diagram</span>
</div>

What about SSB Ticketing System then?

There was no need of parser for SSB Ticketing System. monit tool was already developed by CMS team. It queries InfluxDB/ES data sources in MONIT via Grafana proxy. The SSB alerts in JSON format is printed on std output. We piped stdout to .json file and saved it to the disk. This fulfills the goal of the parser.

Ref :- <a target="_blank" href="https://github.com/dmwm/CMSMonitoring/blob/master/src/go/MONIT/monit.go">monit</a>

Below is an example of such query.

`monit -query=$query -dbname=$dbname -token=$token -dbid=$dbid > ssb_data.json`

So far we have developed parser and found a way to convert both GGUS & SSB alerts in JSON files. But still we are far away from ingesting them to AlertManager. Let's see how we are doing it, shall we? 

## Alerting Module
<br>
<div style="display: flex; flex-direction: column; align-items: center;">
<img src="/assets/img/cern/alert_mod.png" alt="drawing" width="400"/>
<span>Alerting module diagram</span>
</div>

#### Building Blocks
- fetch
- convert
- post
- get
- delete

<span style="color:red">\*now onwards we will call each ticket from GGUS/SSB as an alert</span>

Let's discuss each block the alerting module is made up of.
- fetch
  - fetches saved JSON GGUS or SSB data from the disk (ggus_parser or monit).
  - maintains a hashmap for last seen alerts so that in future we ignore them to avoid multiple copies. Hashmap is a key, value data structure with fast lookup operation. Here key is alertname and value is the alert data.

- convert
  - fetched alerts are ingested here.
  - those alerts get converted to JSON data which AlertManager API understands.

- post
  - converted JSON data which contains GGUS/SSB alerts is pushed to AlertManager through AlertManager API endpoints.

- get
  - few GGUS/SSB alerts do not have Ending Time, that means it will need to be handled gracefully when they are resolved. So we automate the process of deleting those alerts from AlertManager when they are resolved at the origin.
  - fetches GGUS/SSB alerts from AlertManager.
  - now each fetched alert are checked if it is present in the HashMap (we created in fetch method). If available that means it hasn't been resolved yet. If it is not present in the Hashmap we deduce that the alert has been resolved and no need to keep it in the AlertManager. 
  - bundles all resolved alerts.

- delete
  - all resolved alerts will now have End Time equals to present time.
  - all open ending alerts in AlertManager get new End Time which basically means they are deleted immediately.

## Alerting Service 
<br>
<div style="display: flex; flex-direction: column; align-items: center;">
<img src="/assets/img/cern/alert_srv.png" alt="drawing" width="400"/>
<span>Alerting Service diagram</span>
</div>

Now we are familiar with the parser, alerting module and their functionalities. We will know integrate them to create an alerting service.

- Parser fetches data and saves to disk
- Alerting module gets fetched data as input, converts it and pushes to AM.
- This whole process is bundled as a Linux Service with three commands :-
    - start
    - stop
    - status

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
<br>
<div style="display: flex; flex-direction: column; align-items: center;">
<img src="/assets/img/cern/am.png" alt="drawing" width="300"/>
<span>Diagram showing various sources pushing alerts to AM and admins interacting with AM with various tools.</span>
</div>

Alerting services which have been developed push GGUS & SSB alerts to AM at defined time interval.
Grafana & Prometheus push their alerts to AlertManager as well. AlertManager gives loads of features to handle alerts but it lacks proper UI. So, Karma Dashboard is used to fetch all alerts from AlertManager, and display them in nice and beautiful UI. Slack channels are configured to log alerts when they are fired in AlertManager. 

AlertManager, Slack and Karma give all required info for alerts to our Operational teams.

## Use of Slack, Karma and Alert CLI Tool

#### Slack
- Slack has defined channels for particular service alerts.
- Users are notified about fired alerts.
- AlertManager bots are at work.

<div style="display: flex; flex-direction: column; align-items: center;">
<img src="/assets/img/cern/amTools/slack1.png" alt="drawing"/>
<span>GGUS alerts in Slack</span>
</div>

<div style="display: flex; flex-direction: column; align-items: center;">
<img src="/assets/img/cern/amTools/slack2.png" alt="drawing"/>
<span>SSB alerts in Slack</span>
</div>

#### Karma
- A dashboard which pulls all alerts from AlertManager.
- Availability of multi grids arrangement based on filters.
- Concise and better view than AlertManager.
- Wrote Dockerfile and Kubernetes config files.

<div style="display: flex; flex-direction: column; align-items: center;">
<img src="/assets/img/cern/amTools/karma1.png" alt="drawing"/>
<span>Karma Dashboard view-1</span>
</div>
<br>
<div style="display: flex; flex-direction: column; align-items: center;">
<img src="/assets/img/cern/amTools/karma2.png" alt="drawing"/>
<span>Karma Dashboard view-2</span>
</div>

#### Alert CLI Tool

- gives a nice and clean CLI interface for getting alerts, their details are printed on the terminal itself either in tabular form or JSON format.
- convenient option for operators who prefer command line tools.
- comes with several options such as :-
  - service, severity, tag - Filters
  - sort - Sorting
  - details - For detailed information of an alert
  - json - information in JSON format

<div style="display: flex; flex-direction: column; align-items: center;">
<img src="/assets/img/cern/amTools/alert_tool1.png" alt="drawing"/>
<span>Alert CLI Tool printing all alerts in the alertmanager of type SSB services which are sorted over duration of each alert.</span>
</div>
<br>
<div style="display: flex; flex-direction: column; align-items: center;">
<img src="/assets/img/cern/amTools/alert_tool2.png" alt="drawing"/>
<span>Alert CLI Tool printing all alerts in the alertmanager whose severity values are "high".</span>
</div>
<br>
<div style="display: flex; flex-direction: column; align-items: center;">
<img src="/assets/img/cern/amTools/alert_tool3.png" alt="drawing"/>
<span>Alert CLI Tool printing a specific alert in details.</span>
</div>
<br>
<div style="display: flex; flex-direction: column; align-items: center;">
<img src="/assets/img/cern/amTools/alert_tool4.png" alt="drawing"/>
<span>Alert CLI Tool printing a specific alert in details in json format.</span>
</div>

## Intelligence Module
<br>
<div style="display: flex; flex-direction: column; align-items: center;">
<img src="/assets/img/cern/int/int_mod.png" alt="drawing" width="400"/>
<span>Intelligence module diagram</span>
</div>

It is a data pipeline. Each components are independent of each other. One component receives the data, adds its logic and forwards the processed data to other component.

Why data pipeline ?
- Low coupling
- Freedom of adding or removing components on demand.
- Power of concurrency

What it does ?
- assigns proper severity levels to SSB/GGUS alerts which helps operators to understand the criticality of the infrastructure.
Ex. If Number of Alerts with severity=”urgent” > some threshold, then the infrastructure is in critical situation.
- annotates Grafana Dashboards when Network or Database interventions.
- predicts type of alerts and groups similar alerts with the help of Machine Learning.
- adds applicable tutorial/instructions doc to alert, on following which an operator can solve the issue quickly.
- deletes old silences for those alerts which have open ending (such as GGUS alerts and some SSB alerts having no End time).

#### Building Blocks
- Fetch Alerts
- Preprocessing
- Keyword Matching
- Add Annotations
- Machine Learning
- Push Alert
- Silence Alert
- Delete Old Silences

#### Tools
- AlertManager
- Grafana

#### Fetch Alerts

<div style="display: flex; flex-direction: column; align-items: center;">
<img src="/assets/img/cern/int/fetch_alerts.jpg" alt="drawing" width="250"/>
<span>Fetch Alerts diagram</span>
</div>

- fetches all alerts from AlertManager
- bundles them and put them on a channel.
- channel (Analogy) - baggage belt at Airports. You put data into it, data will be picked up when required by other party.

#### Preprocessing

<div style="display: flex; flex-direction: column; align-items: center;">
<img src="/assets/img/cern/int/preprocessing.jpg" alt="drawing" width="450"/>
<span>Preprocessing diagram</span>
</div>

- filtering based on configuration.
- only filtered alerts are forwarded.
- we also manage one map for keeping track of active silenced alerts to avoid redundant silences.
- if an alert is already silenced that means it has been processed by the intelligence module before.

#### Keyword Matching

<div style="display: flex; flex-direction: column; align-items: center;">
<img src="/assets/img/cern/int/keyword_matching.png" alt="drawing" width="350"/>
<span>Keyword Matching diagram</span>
</div>

- analysis of Alerts showed us repetitive use of a few important keywords.
- these keywords help in assigning severity levels.
- searches for these keywords in alerts, if found we assign severity level mapped to that keyword.

#### Add Annotations

<div style="display: flex; flex-direction: column; align-items: center;">
<img src="/assets/img/cern/int/add_annotations.jpg" alt="drawing" width="350"/>
<span>Add Annotations diagram</span>
</div>

- Grafana has dashboards which shows running services’ metrics in the form of graphs.
- Grafana has add Annotation feature.
- SSB alert mentioning intervention in network / DB affects these services.
- pushes such interventions info in the form of annotations into Grafana dashboards.

#### Push Alert 

<div style="display: flex; flex-direction: column; align-items: center;">
<img src="/assets/img/cern/int/push_alert.jpg" alt="drawing" width="400"/>
<span>Push Alert diagram</span>
</div>

- alerts with modified information are pushed to AlertManager
- incoming alerts are then forwarded to Silence Alert.

#### Silence Alert 

<div style="display: flex; flex-direction: column; align-items: center;">
<img src="/assets/img/cern/int/silence_alert.png" alt="drawing" width="400"/>
<span>Silence Alert diagram</span>
</div>

- alerts which get modified and pushed to AlertManager get copied.
- older alert is redundant
- silences the older one for the duration of its lifetime.

#### Delete Old Silences 

<div style="display: flex; flex-direction: column; align-items: center;">
<img src="/assets/img/cern/int/delete_old_silences.png" alt="drawing" width="400"/>
<span>Silence Alert diagram</span>
</div>

- Alerts like GGUS & some SSB tickets have open ending time (That means we don't know for how long they will be in AM).
- So we wait for those alerts to get resolved, whenever they are resolved they are deleted from the AM by alerting services.
- But the silences will remain, right ? So, this component takes care of such cases. 
- It delete those silences which get resolved.

<!-- ## Future Work

- Evaluation of ElastAlert for setting alerts on ElasticSearch and integration of the same in this project.
- Service which takes configuration for operator’s actions and pushes to AM so that it matches alerts with the actions.
- Use of Machine Learning in intelligence module which will predict it’s severity info, priority and type.
- Deployment of finalized project to k8s infrastructure. -->

## Tools Used

- Programming Language

  <img style="margin-left:0px;" src="/assets/img/cern/logo/golang.png"/>

- Editor

    <div style="display:flex;">
    <img style="margin-left:0px; margin-right:10px;"  src="/assets/img/cern/logo/vim.svg" width="48px"/>
    <img style="margin-left:0px; margin-right:10px;"  src="/assets/img/cern/logo/vccode.png" />
    </div>

- Helper Tools

    <div style="display:flex;">
    <img style="margin-left:0px; margin-right:10px;"  src="/assets/img/cern/logo/github.png" />
    <img style="margin-left:0px; margin-right:10px;"  src="/assets/img/cern/logo/git.png"/>
    <img style="margin-left:0px; margin-right:10px;"  src="/assets/img/cern/logo/golint.png" width="130px"/>
    </div>
    <div style="display:flex;">
    <img style="margin-left:0px; margin-right:10px;"  src="/assets/img/cern/logo/ps.png"/>
    <img style="margin-left:0px; margin-right:10px;"  src="/assets/img/cern/logo/gdocs.png"/>
    <img style="margin-left:0px; margin-right:10px;"  src="/assets/img/cern/logo/gslides.png"/>
    </div>

## Acknowledgements

I am thankful to my mentors for their invaluable guidance and support throught my GSoC journey.

### Mentor details

{% for mentor in site.data.people.mentors %}
 <div class="mentor-detail" style="display:flex;  ">
<img style="margin-left:0px; margin-right:10px; border-radius: 100%; object-fit: cover;" src="{{mentor.link}}" height="{{mentor.ht}}" width="{{mentor.wt}}" />
 <a style="text-decoration:none;" href="mailto:{{mentor.email}}">{{mentor.name}} <br> {{mentor.pos}}</a>
    </div>
{% endfor %}

### Contact Me
{% for mentor in site.data.people.me %}
 <div class="mentor-detail" style="display:flex; ">
<img style="margin-left:0px; margin-right:10px; border-radius: 100%; object-fit: cover;" src="{{mentor.link}}" height="{{mentor.ht}}" width="{{mentor.wt}}" />
 <a style="text-decoration:none;" >{{mentor.name}} <br> {{mentor.pos}}</a>
    </div>
{% endfor %}
- Feel free to send me a mail at <a href="mailto:indrarahul2018@gmail.com">indrarahul2018@gmail.com</a>
- Raise issues if any at:
  - <a target="_blank" href="https://github.com/dmwm/CMSMonitoring">CMSMonitoring</a>
