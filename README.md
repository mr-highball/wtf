----------------
+   WTF Core   +
----------------

Purpose: 
----------------
Need a classification framework which allows several trained/traditional 
models to work in unison and "vote" for what they believe to be
the correct classification. The ultimate goal for this is to
provide a single input, which is passed down to many members
who vote on what the classification based on data fed to them,
then bubbled up back to the caller.


Manager:
----------------
High level controller of multiple models, and when provided data,
will pass along to all models in the group. When a manager is asked
to give a report on the current state of data, he will ask all models
for their input on the classification, but will not treat all models
as equal (weighted trustworthiness). Based on their weights, will give 
the caller the best guess of what the classification is, as well as a
guid which can be used to provide back to the manager stating what the correct
classification actually was. This feedback process will allow the manager to 
re-adjust biases from his collection of models and hopefully adjust to the
conditions of the environment, without having to re-train models.

The common elements that a manager must have:

-What data the manager operates with
-What are the classifications that the manager can provide
-Feed Data
-Classify Method
-Provide Feedback (guid, and what the actual classification was supposed to be)

Model:
----------------
A model can use any sort of mechanism to determine what sort of 
classification the current state the data provided to it is in.

The common elements that a model must have:

-What data the model operates with
-What are the classifications that the model can provide 
-Feed Data
-Classify Method
