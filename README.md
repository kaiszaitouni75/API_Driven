------------------------------------------------------------------------------------------------------
ATELIER API-DRIVEN INFRASTRUCTURE
------------------------------------------------------------------------------------------------------
L’idée en 30 secondes : **Orchestration de services AWS via API Gateway et Lambda dans un environnement émulé**.  
Cet atelier propose de concevoir une architecture **API-driven** dans laquelle une requête HTTP déclenche, via **API Gateway** et une **fonction Lambda**, des actions d’infrastructure sur des **instances EC2**, le tout dans un **environnement AWS simulé avec LocalStack** et exécuté dans **GitHub Codespaces**. L’objectif est de comprendre comment des services cloud serverless peuvent piloter dynamiquement des ressources d’infrastructure, indépendamment de toute console graphique.Cet atelier propose de concevoir une architecture API-driven dans laquelle une requête HTTP déclenche, via API Gateway et une fonction Lambda, des actions d’infrastructure sur des instances EC2, le tout dans un environnement AWS simulé avec LocalStack et exécuté dans GitHub Codespaces. L’objectif est de comprendre comment des services cloud serverless peuvent piloter dynamiquement des ressources d’infrastructure, indépendamment de toute console graphique.
  
-------------------------------------------------------------------------------------------------------
Séquence 1 : Codespace de Github
-------------------------------------------------------------------------------------------------------
Objectif : Création d'un Codespace Github  
Difficulté : Très facile (~5 minutes)
-------------------------------------------------------------------------------------------------------
RDV sur Codespace de Github : <a href="https://github.com/features/codespaces" target="_blank">Codespace</a> **(click droit ouvrir dans un nouvel onglet)** puis créer un nouveau Codespace qui sera connecté à votre Repository API-Driven.
  
---------------------------------------------------
Séquence 2 : Création de l'environnement AWS (LocalStack)
---------------------------------------------------
Objectif : Créer l'environnement AWS simulé avec LocalStack  
Difficulté : Simple (~5 minutes)
---------------------------------------------------

Dans le terminal du Codespace copier/coller les codes ci-dessous etape par étape :  

**Installation de l'émulateur LocalStack**  
```
sudo -i mkdir rep_localstack
```
```
sudo -i python3 -m venv ./rep_localstack
```
```
sudo -i pip install --upgrade pip && python3 -m pip install localstack && export S3_SKIP_SIGNATURE_VALIDATION=0
```
```
localstack start -d
```
**vérification des services disponibles**  
```
localstack status services
```
**Réccupération de l'API AWS Localstack** 
Votre environnement AWS (LocalStack) est prêt. Pour obtenir votre AWS_ENDPOINT cliquez sur l'onglet **[PORTS]** dans votre Codespace et rendez public votre port **4566** (Visibilité du port).
Réccupérer l'URL de ce port dans votre navigateur qui sera votre ENDPOINT AWS (c'est à dire votre environnement AWS).
Conservez bien cette URL car vous en aurez besoin par la suite.  

Pour information : IL n'y a rien dans votre navigateur et c'est normal car il s'agit d'une API AWS (Pas un développement Web type UX).

---------------------------------------------------
Séquence 3 : Exercice
---------------------------------------------------
Objectif : Piloter une instance EC2 via API Gateway
Difficulté : Moyen/Difficile (~2h)
---------------------------------------------------  
Votre mission (si vous l'acceptez) : Concevoir une architecture **API-driven** dans laquelle une requête HTTP déclenche, via **API Gateway** et une **fonction Lambda**, lancera ou stopera une **instance EC2** déposée dans **environnement AWS simulé avec LocalStack** et qui sera exécuté dans **GitHub Codespaces**. [Option] Remplacez l'instance EC2 par l'arrêt ou le lancement d'un Docker.  

**Architecture cible :** Ci-dessous, l'architecture cible souhaitée.   
  
![Screenshot Actions](API_Driven.png)   
  
---------------------------------------------------  
## Processus de travail (résumé)

1. Installation de l'environnement Localstack (Séquence 2)
2. Création de l'instance EC2
3. Création des API (+ fonction Lambda)
4. Ouverture des ports et vérification du fonctionnement

---------------------------------------------------
Séquence 4 : Documentation  
Difficulté : Facile (~30 minutes)
---------------------------------------------------
**Complétez et documentez ce fichier README.md** pour nous expliquer comment utiliser votre solution.  
Faites preuve de pédagogie et soyez clair dans vos expliquations et processus de travail.  

##Explication de la solution.

Pour utiliser la solution il suffit de lancer le script **setup.sh** 
Si vous rencontrz des problèmes pour l'execution du script essayez
**chmod +x setup.sh**
**sudo ./setup.sh**

Une fois le sript terminer un cadre apparaît avec la commande **make** suivi de **start** **stop** **status**, il s'agit d'outil des paramêtre pour gérer votre instance
---------------------------------------------------
Evaluation
---------------------------------------------------
Cet atelier, **noté sur 20 points**, est évalué sur la base du barème suivant :  
- Repository exécutable sans erreur majeure (4 points)
- Fonctionnement conforme au scénario annoncé (4 points)
- Degré d'automatisation du projet (utilisation de Makefile ? script ? ...) (4 points)
- Qualité du Readme (lisibilité, erreur, ...) (4 points)
- Processus travail (quantité de commits, cohérence globale, interventions externes, ...) (4 points) 
