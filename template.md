# Strimzi demo for Kafka Summit 2021

Demo for using Strimzi to manage a Kafka cluster on Kubernetes.

## Prerequisities
- Kubernetes cluster
- Namespace context set to `myproject`

# Demo
Today we are going to demonstrate the Strimzi Kafka Operator for running Kafka on Kubernetes. 
```
0-overview.txt
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
kubectl apply -f examples/kafka-ephemeral.yaml
```

```
1-single-broker-cluster.txt
```

Here we are passing Kubernetes a description of a `Kafka` custom resource object. 
The Strimzi Cluster Operator will then read the descriptionof the newly created `Kafka` resource object and create a Kafka cluster based on that description. 
We can think of the `Kafka` resource as a blueprint and the operator as a builder.

Let's take a closer look at the description of the Kafka resource we just passed to Kubernetes 
```
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
      type: ephemeral
  zookeeper:
    replicas: 1
    storage:
      type: ephemeral
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

Now that we have our Kafka cluster up and running we can start using it. 

Let's start by creating a Kafka topic that we can read and write messages to.

Just as with Kafka clusters, we can create and manage Kafka topics using custom resources as well.

Where as Kafka clusters are managed by the Strimzi _Cluster_ Operator, Kafka topics are managed by the Strimzi _Topic_ Operator.

We can deploy the Topic Operator by editing our `Kafka` resource in the following manner:

```
kind: Kafka
metadata:
  name: my-cluster
spec:
  kafka:
  ...
  entityOperator:
    topicOperator: {}

```

The Cluster Operator will notice these changes in the `Kafka` resource and deploy the Topic Operator alongside our Kafka cluster.

```
2-topic-operator.txt
```
Now that we have the Topic Operator up and running, we can pass it a description of our topic using a `KafkaTopic` resource
```
kubectl apply -f examples/kafka-topic.yaml
```
```
3-topic-resource.txt
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
  partitions: 1
  replicas: 3
  config:
    retention.ms: 7200000
    segment.bytes: 1073741824
```

As we can see in the description in the `KafkaTopic` resource, we describe a Kafka Topic that
- Contains 1 partition
- Contains 3 replicas per partition
- Has the following Apache Kafka topic configurations

*Note*: The 3 replicas are irrelevant right now since we only have one broker but will be important for when we scale the cluster later.

The Kubernetes CLI makes it convenient for interacting with topics whether you use it to view your topics

```
kubectl get KafkaTopic
```

or update them:

```
kubectl edit KafkaTopic my-topic
```

Now that we have a KafkaTopic, let's write and read messages to it!

## Reading and writing messages to the cluster

Let's create a basic Kafka producer and consumer to write and read messages from our single node cluster:

- (Split window pane) -

LEFT
```
kubectl apply -f examples/java-kafka-producer.yaml
```
then
```
kubectl logs pod/java-kafka-producer -f
```

RIGHT
```
kubectl apply -f examples/java-kafka-consumer.yaml
```
```
kubectl logs pod/java-kafka-consumer -f
```

## Scaling

This is all well and good but as you all know  and can see here, all of our topic's partitions and replicas are piled up on one broker:

```
kubectl exec -ti my-cluster-kafka-0 -- ./bin/kafka-topics.sh --describe --bootstrap-server localhost:9092 --topic my-topic
```

It's the same story for all of our internal topics.

```
kubectl exec -ti my-cluster-kafka-0 -- ./bin/kafka-topics.sh --describe --bootstrap-server localhost:9092
```

If we were to lose this Kafka broker right now, we would lose everything! (including our precious "hello world" messages)

Let's make our cluster more robust by adding more Kafka brokers to our cluster 

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
4-scaled.txt
```
Just like every other change to our cluster, all we need to do is update the description of our `kafka` resource and the Cluster Operator will do the rest.

Although we have 3 brokers now, all of our partitions and replicas are still piled up on broker 0!

```
kubectl exec -ti my-cluster-kafka-0 -- ./bin/kafka-topics.sh --describe --bootstrap-server my-cluster-kafka-bootstrap:9092
```

We need to redistribute these partitions to balance our cluster out.

## Cluster balancing

To balance our partitions accross our brokers we can use Cruise Control, an opensource project for balancing workloads along Kafka brokers.

Strimzi's Cruise Control integration makes it easy to use Cruise Control in Kubernetes.

We can deploy Cruise Control in a similar fashion to how we deployed the Topic Operator, through the `kafka` custom resource:

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
5-cruise-control.txt
```

We can see Cruise Control deployed here
```
kubectl get pods
``

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
which would cause Cruise Control to balance the cluster based on broker disk capacity, ignoring other factors like
- CPU load
- Network load
- etc
The defult settings cover all of these factors

```
6-rebalance-resource.txt
```

This `KafkaRebalance` resource will be read by the Cluster Operator to form a rebalance proposal request to the Cruise Control API.

After receiving the optimization proposal from Cruise Control, the Cluster Operator will subsequently update the `KafkaRebalance` resource with the details of this partition rebalance plan for review.

We can look at the rebalance plan like this
```
kubectl describe kafkarebalance my-rebalance -n myproject
```

If all looks good, we can execute the rebalance based on that proposal, by annotating the `KafkaRebalance` resource like this:

```
kubectl annotate kafkarebalance my-rebalance strimzi.io/rebalance=approve
```

Now Cruise Control will execute a partition rebalance amongst the brokers

Once complete, we can look
```
kubectl exec -ti my-cluster-kafka-0 -- ./bin/kafka-topics.sh --describe --bootstrap-server my-cluster-kafka-bootstrap:9092
```
