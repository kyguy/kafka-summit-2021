# Strimzi demo for Kafka Summit 2021

Demo for using Strimzi to manage a Kafka cluster on Kubernetes.

## Prerequisities
- Kubernetes cluster
- Namespace context set to `myproject`

# Demo
Today we are going to demonstrate the Strimzi Kafka Operator for running Kafka on Kubernetes. 
```
                                                    *  *         *  *          *  * 
    +----------+                                 *        *   *        *    *        * 
  +----------+ |                                *  Kafka   * *  Kafka   *  *  Kafka   * 
+----------+ | |               *  *             *   Pod    * *   Pod    *  *   Pod    * 
|          | | |            *       *            *        *   *        *    *        * 
|  Custom  | | | <------+  * Strimzi  * ----->      *  *         *  *          *  * 
| Resource | | | +------>  * Operator * 
|          | |-+            *        *              *  *         *  *          *  * 
|          |-+                *  *               *        *   *        *    *        * 
+----------+                                    * Zookeeper* * Zookeeper*  * Zookeeper* 
                                                *   Pod    * *   Pod    *  *   Pod    * 
                                                 *        *   *        *    *        * 
                                                    *  *         *  *          *  * 
 
                                                             Kafka Cluster 
 
 
Kubernetes Land 
```
In this demo, we will cover a few things like:
- How to install the Strimzi Kafka Operator.
- How to deploy and manage a Kafka cluster.
- Advanced integration features like Cruise Control and Kafka Connect.

## Cluster Deployment

Let's start by deploying the Strimzi Cluster Operator to Kubernetes.

```
curl -L strimzi.io/install/latest | kubectl create -f -
```

This command will download a Strimzi installation file which defines Strimzi using Kubernetes objects:

- CustomResourceDefinitions
- ClusteRoles
- ConfigMaps
- Deployments

Then these objects will then be created in Kubernetes.

As we can see here, our the deployment for the Strimzi Cluster Operator was created.

```
kubectl get pods
```

We can also see the Strimzi CustomResourceDefinitions that were created as well.

```
kubectl get crds
```

These CustomResourceDefinitions will allow us to create Strimzi objects like:
- `Kafka` objects
- `KafkaTopic` objects
- `KafkeUser` objects
- etc

Now we can deploy a Kafka cluster like this: 
```
kubectl apply -f examples/kafka-persistent.yaml
```

```
                                            Kafka Cluster

                                                *  *
                                             *        *
+----------+                                *  Kafka   *
|          |               *  *             *   Pod    *
|  Kafka   |            *        *           *        *
| Resource | <------+  * Cluster  * ----->      *  *
|          | +------>  * Operator *
|          |            *        *              *  *
+----------+               *  *              *        *
                                            * Zookeeper*
                                            *   Pod    *
                                             *        *
                                                *  *
Kubernetes Land
```

Here we are passing Kubernetes a description of a `Kafka` custom resource object. 
The Strimzi Cluster Operator will then read the description of the newly created `Kafka` resource object and create a Kafka cluster based on that description. 
We can think of the `Kafka` resource as a blueprint and the operator as a builder.

Let's take a closer look at the description of the Kafka resource we just passed to Kubernetes 
```
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: my-cluster
spec:
  kafka:
    version: 2.7.0
    replicas: 1
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
      - name: tls
        port: 9093
        type: internal
        tls: true
    config:
      offsets.topic.replication.factor: 1
      transaction.state.log.replication.factor: 1
      transaction.state.log.min.isr: 1
      log.message.format.version: "2.7"
      inter.broker.protocol.version: "2.7"
    storage:
      type: jbod
      volumes:
      - id: 0
        type: persistent-claim
        size: 10Gi
        deleteClaim: false
  zookeeper:
    replicas: 1
    storage:
      type: persistent-claim
      size: 10Gi
      deleteClaim: false
```

We define a Kafka cluster that 
- Runs Apache Kafka broker version 2.7.0
- Has one broker pod replica (or instance)
- Has the following broker configuration.

Here we can see the Cluster Operator has created a single-node Kafka cluster:
```
kubectl get pods
``` 

With this cluster, there are a few things Strimzi gives us for free out of the box:
- **Security**: All communication within the cluster is encryted and authenticated by default.
- **Automated configuration management**: When we update the Kafka resource, the changes are automatically applied to all of the brokers in the cluster.

## Managing the Cluster

Just as we can manage Kafka clusters using the Strimzi _Cluster_ Operator, we can manage other Kafka components using the Strimzi _Entity_ Operator. Namely
- Kafka topics
- Kafka users

We can deploy the Entity Operator by editing our `Kafka` resource in the following manner:

```
kind: Kafka
metadata:
  name: my-cluster
spec:
  kafka:
  ...
  entityOperator:
    topicOperator: {}
    userOperator: {}
```

Notice the Entity Operator comprises of two operators:
- An operator for managing Kafka Topics
- An operator for managing Kafka Users

```

                           *  *
                        *        *
                       *  Entity  *
                       * Operator *         Kafka Cluster
                        *        *
                           *  *                 *  *
                            ^                *        *
                            |               *  Kafka   *
+----------+                |               *   Pod    *
|          |               *  *              *        *
|  Kafka   |            *        *              *  *
| Resource | <------+  * Cluster  * ----->
|          | +------>  * Operator *             *  *
|          |            *        *           *        *
+----------+               *  *             * Zookeeper*
                                            *   Pod    *
                                             *        *
                                                *  *

Kubernetes Land
```

The Cluster Operator will notice these changes in the `Kafka` resource and deploy the Entity Operator alongside our Kafka cluster.

### Kafka topics

Now that we have the Entity Operator up and running, let's create a Kafka topic.

Here we pass Kubernetes a description of our desired `KafkaTopic` resource

```
kubectl apply -f examples/kafka-topic.yaml
```

```
+----------+
|          |               *  *
|  Topic   |            *        *
| Resource | <------+ *   Entity  *
|          | +------> *  Operator *---+     Kafka Cluster
|          |            *        *    |
+----------+               *  *       |         *  *
                            ^         |      *        *
                            |         +-->  *  Kafka   *
+----------+                |               *   Pod    *
|          |               *  *              *        *
|  Kafka   |            *        *              *  *
| Resource | <------+  * Cluster  * ----->
|          | +------>  * Operator *             *  *
|          |            *        *           *        *
+----------+               *  *             * Zookeeper*
                                            *   Pod    *
                                             *        *
                                                *  *

Kubernetes Land
```

Just like our `Kafka` resource, our `KafkaTopic` resource is a custom Strimzi resource that we describe in a yaml and pass to our Operator to turn that description into reality.

Let's look at the `KafkaTopic` resource we just passed our Operator
```
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: my-topic
  labels:
    strimzi.io/cluster: my-cluster
spec:
  partitions: 3
  replicas: 1
  config:
    retention.ms: 7200000
    segment.bytes: 1073741824
```

As we can see in the description in the `KafkaTopic` resource, we describe a Kafka Topic that
- Contains 3 partitions
- Contains 1 replicas per partition
- Has the following Apache Kafka topic configurations

The Kubernetes CLI makes it convenient for interacting with topics whether you use it to view your topics

```
kubectl get KafkaTopic
```

or update them:

```
kubectl edit KafkaTopic my-topic
```

### Kafka users

Let's now create a Kafka user that can use this topic.

With the Entity Operator already running, we can pass it a description of a `KafkaUser` resource.

```
kubectl apply -f examples/kafka-user.yaml
```

Let's look at the description of the `KafkaUser` resource we just passed our Operator

```
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaUser
metadata:
  name: my-user
  labels:
    strimzi.io/cluster: my-cluster
spec:
  authentication:
    type: tls
  authorization:
    type: simple
    acls:
      # Example consumer Acls for topic my-topic using consumer group my-group
      - resource:
          type: topic
          name: my-topic
          patternType: literal
        operation: Read
        host: "*"
      - resource:
          type: topic
          name: my-topic
          patternType: literal
        operation: Describe
        host: "*"
      - resource:
          type: group
          name: my-group
          patternType: literal
        operation: Read
        host: "*"
      # Example Producer Acls for topic my-topic
      - resource:
          type: topic
          name: my-topic
          patternType: literal
        operation: Write
        host: "*"
      - resource:
          type: topic
          name: my-topic
          patternType: literal
        operation: Create
        host: "*"
      - resource:
          type: topic
          name: my-topic
          patternType: literal
        operation: Describe
        host: "*"
```
Here in our KafkaUser resource, we declare a few things:
- TLS client authentication
- Access Control Lists (ACLs)

```
+----------+
|          |               *  *
|   User   |            *        *
| Resource | <------+ *   Entity  *
|          | +------> *  Operator *---+     Kafka Cluster
|          |            *        *    |
+----------+               *  *       |         *  *
                            ^         |      *        *
                            |         +-->  *  Kafka   *
+----------+                |               *   Pod    *
|          |               *  *              *        *
|  Kafka   |            *        *              *  *
| Resource | <------+  * Cluster  * ----->
|          | +------>  * Operator *             *  *
|          |            *        *           *        *
+----------+               *  *             * Zookeeper*
                                            *   Pod    *
                                             *        *
                                                *  *

Kubernetes Land
```

```
kubectl get KafkaUsers
```

The User Operator has now create an authenticated Kafka user that is authorized to read and write to the topic which we have created in our Kafka broker.

## Reading and writing messages to the cluster

Now that we have our Kafke topic and Kafka user set up we can start reading and writing messages to our Kafka cluster:

Let's deploy some simple producer and consumer apps.
LEFT
```
kubectl apply -f examples/producer-consumer-deployment.yaml
```

Looking at the deployment 
```
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: java-kafka-producer
  name: java-kafka-producer
spec:
  replicas: 1
  selector:
    matchLabels:
      app: java-kafka-producer
  template:
    metadata:
      labels:
        app: java-kafka-producer
    spec:
      containers:
      - name: java-kafka-producer
        image: quay.io/strimzi-examples/java-kafka-producer:latest
        env:
          - name: CA_CRT
            valueFrom:
              secretKeyRef:
                name: my-cluster-cluster-ca-cert
                key: ca.crt
          - name: USER_CRT
            valueFrom:
              secretKeyRef:
                name: my-user
                key: user.crt
          - name: USER_KEY
            valueFrom:
              secretKeyRef:
                name: my-user
                key: user.key
          - name: BOOTSTRAP_SERVERS
            value: my-cluster-kafka-bootstrap:9093
          - name: TOPIC
            value: my-topic
          - name: DELAY_MS
            value: "1000"
          - name: LOG_LEVEL
            value: "INFO"
          - name: MESSAGE_COUNT
            value: "1000000"
...
```

As we can see:
- We point our clients to use the secure bootstrap address of our cluster on port 9093 which only allows authenticated traffic.
- We point our clients to use the `my-user` secret created by the User Operator to tie the clients to that Kafka user. 

**Note** No other client will be able to read or write to our topic using the secure Kafka port. We do expose the cluster to unauthenticated traffic on port 9092, but we could have easily restricted it.

Let's look at the messages moving through our Kafka broker

(Split window pane left)

```
kubectl logs java-kafka-producer -f
```

(Split window pane right)

```
kubectl logs java-kafka-consumer -f
```

We can see messaged being written to our Kafka broker on the left and read from the Kafka broker on the right.

## Scaling

This is all well and good but as you all know, all of our topic's partitions are piled up on one broker:

```
kubectl exec -ti my-cluster-kafka-0 -- ./bin/kafka-topics.sh --describe --bootstrap-server localhost:9092 --topic my-topic
```

It's the same story for all of our internal topics.

```
kubectl exec -ti my-cluster-kafka-0 -- ./bin/kafka-topics.sh --describe --bootstrap-server localhost:9092
```

Our cluster can't reach it's full potential by having all of its partitions on one broker. 

Scale our cluster by adding more Kafka brokers to our cluster. 

Let's scale our cluster to 3 Kafka brokers
```
kind: Kafka
metadata:
  name: my-cluster
spec:
  kafka:
    ...
    replicas: 3
    ...
```

```
                                                        Kafka Cluster

                                                *  *         *  *          *  *
                                             *        *   *        *    *        *
+----------+                                *  Kafka   * *  Kafka   *  *  Kafka   *
|          |               *  *             *   Pod    * *   Pod    *  *   Pod    *
|  Kafka   |            *        *            *        *   *        *    *        *
| Resource | <------+  * Cluster  * ----->      *  *         *  *          *  *
|          | +------>  * Operator *
|          |            *        *              *  *         *  *          *  *
+----------+               *  *              *        *   *        *    *        *
                                            * Zookeeper* * Zookeeper*  * Zookeeper*
                                            *   Pod    * *   Pod    *  *   Pod    *
                                             *        *   *        *    *        *
                                                *  *         *  *          *  *
Kubernetes Land
```
Just like every other change to our cluster, all we need to do is update the description of our `kafka` resource and the Cluster Operator will do the rest.

Although we have 3 brokers now, all of our partitions are still piled up on broker 0!

```
kubectl exec -ti my-cluster-kafka-0 -- ./bin/kafka-topics.sh --describe --bootstrap-server my-cluster-kafka-bootstrap:9092
```

We need to redistribute these partitions to balance our cluster out.

## Cluster balancing

To balance our partitions accross our brokers we can use Cruise Control, an opensource project for balancing workloads along Kafka brokers.

Strimzi's Cruise Control integration makes it easy to use Cruise Control in Kubernetes.

We can deploy Cruise Control in a similar fashion to how we deployed the Entity Operator, through the `kafka` custom resource:

```
kind: Kafka
metadata:
  name: my-cluster
spec:
  ...  
  kafka:
  ...
  cruiseControl: {}
```
The Cluster Operator will notice these changes in the `Kafka` resource and deploy Cruise Control alongside our Kafka cluster.
```
                           *  *
                        *        *
                       * Cruise   *
                       * Control  *
                        *        *
                          *  *
                            ^                   *  *         *  *          *  *
                            |                *        *   *        *    *        *
+----------+                |               *  Kafka   * *  Kafka   *  *  Kafka   *
|          |               *  *             *   Pod    * *   Pod    *  *   Pod    *
|  Kafka   |           *        *           *        *   *        *    *        *
| Resource | <------+  * Cluster  * ----->      *  *         *  *          *  *
|          | +------>  * Operator *
|          |            *        *              *  *         *  *          *  *
+----------+               *  *              *        *   *        *    *        *
                                            * Zookeeper* * Zookeeper*  * Zookeeper*
                                            *   Pod    * *   Pod    *  *   Pod    *
                                             *        *   *        *    *        *
                                                *  *         *  *          *  *

Kubernetes Land                                          Kafka Cluster
```

We can see Cruise Control deployed here
```
kubectl get pods
```

Now that Cruise Control has been deployed, we need a way of interacting with the Cruise Control.
Luckily, just like for all other Kafka components, Strimzi provides a way of interacting with the Cruise Control API using the Kubernetes CLI.

First we must create a `KafkaRebalance` resource like this:
```
kubectl apply -f examples/kafka-rebalance.yaml
```
This will serve as our medium to Cruise Control for preforming a partition rebalance.

Taking a closer look at the `KafkaRebalance` resource:
```
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaRebalance
metadata:
  name: my-rebalance
  labels:
    strimzi.io/cluster: my-cluster
# no goals specified, using the default goals from the Cruise Control configuration
spec: {}
```
We can see it is pretty simple, especially since we are relying on the default configurations.
We could have specified a custom `spec.goals` list to optimize how the cluster is balanced.
For example, we could have added a single value `spec.goals` list with

- DiskCapacityGoal

which would cause Cruise Control to balance the cluster based on broker disk capacity, ignoring other factors like:

- CPU load
- Network load
- ReplicaCapacity
- etc

The defult settings cover all of these factors anyway

```
                           *  *
                        *        *
                       * Cruise   * -------------+------------+------------+
                       * Control  *              |            |            |
                        *        *               v            v            v
                          *  *
                            ^                   *  *         *  *          *  *
                            |                *        *   *        *    *        *
+----------+                |               *  Kafka   * *  Kafka   *  *  Kafka   *
|          |               *  *             *   Pod    * *   Pod    *  *   Pod    *
|  Kafka   |            *        *            *        *   *        *    *        *
| Resource | <------+  * Cluster  * ----->      *  *         *  *          *  *
|          | +------>  * Operator *
|          |            *        *              *  *         *  *          *  *
+----------+               *  *              *        *   *        *    *        *
                            | ^             * Zookeeper* * Zookeeper*  * Zookeeper*
+----------+                | |             *   Pod    * *   Pod    *  *   Pod    *
|          |                | |              *        *   *        *    *        *
|Rebalance | <--------------+ |                 *  *         *  *          *  *
| Resource | +----------------+
|          |                                             Kafka Cluster
|          |
+----------+


Kubernetes Land
```

This `KafkaRebalance` resource will be read by the Cluster Operator to form a rebalance proposal request to the Cruise Control API.

After receiving the optimization proposal from Cruise Control, the Cluster Operator will subsequently update the `KafkaRebalance` resource with the details of this partition rebalance plan for review.

We can look at the rebalance plan like this
```
kubectl describe kafkarebalance my-rebalance
```
```
Status:
  Conditions:
    Last Transition Time:  2021-05-06T21:56:27.023127Z
    Status:                True
    Type:                  ProposalReady
  Observed Generation:     1
  Optimization Result:
    Data To Move MB:  0
    Excluded Brokers For Leadership:
    Excluded Brokers For Replica Move:
    Excluded Topics:
    Intra Broker Data To Move MB:         0
    Monitored Partitions Percentage:      100
    Num Intra Broker Replica Movements:   0
    Num Leader Movements:                 8
    Num Replica Movements:                90
    On Demand Balancedness Score After:   86.5211909515508
    On Demand Balancedness Score Before:  78.70730590478658
    Provision Recommendation:             
    Provision Status:                     RIGHT_SIZED
    Recent Windows:                       1
  Session Id:                             50c4ee47-aae3-4ca4-ac49-fffdcecf5834
Events:                                   <none>
```

If all looks good, we can execute the rebalance based on that proposal, by annotating the `KafkaRebalance` resource like this:

```
kubectl annotate kafkarebalance my-rebalance strimzi.io/rebalance=approve
```

Now Cruise Control will execute a partition rebalance amongst the brokers

While we wait for the rebalance to complete let's go through some of the status fields of the `KafkaRebalance` resource.

We can get the status of the rebalance by looking at the resource:

```
kubectl describe kafkarebalance my-rebalance
```

Once complete, we can look and see the partitions and replicas spread amongst all of the brokers.

```
kubectl exec -ti my-cluster-kafka-0 -- ./bin/kafka-topics.sh --describe --bootstrap-server my-cluster-kafka-bootstrap:9092
```
```
Topic: __consumer_offsets	Partition: 0	Leader: 0	Replicas: 0	Isr: 0
Topic: __consumer_offsets	Partition: 1	Leader: 1	Replicas: 1	Isr: 1
Topic: __consumer_offsets	Partition: 2	Leader: 1	Replicas: 1	Isr: 1
Topic: __consumer_offsets	Partition: 3	Leader: 1	Replicas: 1	Isr: 1
Topic: __consumer_offsets	Partition: 4	Leader: 2	Replicas: 2	Isr: 2
Topic: __consumer_offsets	Partition: 5	Leader: 2	Replicas: 2	Isr: 2
```
