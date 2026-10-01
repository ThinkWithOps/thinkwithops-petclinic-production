# Changelog

## [1.1.1](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/compare/petclinic-v1.1.0...petclinic-v1.1.1) (2026-10-01)


### Documentation

* bring README up to date with verified V2 state ([386b15e](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/386b15ebeb9b3073e682ff324fa7ca053380a7af))
* mark release digest promotion verified (petclinic-v1.1.0) ([#8](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/issues/8)) ([2d1ad73](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/2d1ad7344ca3c30c791a7dc6b8a819255073a93c))

## [1.1.0](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/compare/petclinic-v1.0.2...petclinic-v1.1.0) (2026-10-01)


### Features

* add V1 containerized DevOps layer for PetClinic ([7fc3b7d](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/7fc3b7df6bef376db2b1eebddce429a61a2eb657))


### Bug Fixes

* accept 3 fixable-CRITICAL Tomcat CVEs via time-boxed .trivyignore ([ac1342b](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/ac1342ba27748f36cca713a45168d6d6c59bd4d2))
* add explicit deny-by-default top-level permissions to workflows ([a23aacf](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/a23aacfc9d9f6c294a5943339697e9df42c98ed8))
* add USER + HEALTHCHECK to ci/jenkins/Dockerfile for Checkov ([f413bd8](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/f413bd806ab35f375d1b64aa4fb42b30c97c77c8))
* document release 1.0.2 stale-label root cause in v2 validation ([#6](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/issues/6)) ([4f8a674](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/4f8a6744a66c448a61efe41cfe3eefd401afa565))
* lowercase GHCR image repository path ([8d7265d](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/8d7265d1f7cff3251bb9d659e5664a91394e4cf1))
* make digest-equality proof robust instead of fragile JSON grep ([9039216](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/90392167826c6fcea74fa6738ee2716e0815dfb1))
* match sonar.projectKey to the real SonarCloud project key ([572cd87](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/572cd87e04f083d189c9fd516c894cad0c8bbad7))
* pin actions by real commit SHA, fix trivy-action tag, fix sonar config being silently ignored ([db43693](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/db43693f12d757902e4d1a66588e33522c081b62))
* pin actions by real commit SHA, fix trivy-action tag, fix sonar config being silently ignored ([b579291](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/b5792913cc58d5264bf661986bda16848772f2bb))
* quote actuator-blocking regex in nginx config ([5a1a706](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/5a1a706ff3f4f54523620931774b26cad5728663))
* race condition — release.yml ran concurrently with ci.yml, not after it ([3e51464](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/3e5146451718a4ab7ad90bd2fe3c295bf047ab5c))
* release-please PR never triggers CI; sync README/docs with real CI results ([5fe08af](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/5fe08af88b4b8dd4465a741e9ec63453c56aa11e))
* restore executable bit on all shell scripts ([2da34f7](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/2da34f76294ca8a80a3ee8c99327f6f5f14aac8f))
* restore executable bit on gradlew and mvnw ([3f9cb30](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/3f9cb301819b0140dc7ef3abacc95c6fe9424ac6))
* restore V1 troubleshooting entries lost by a bad heredoc append ([04a7b35](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/04a7b35a170967a9520d36be653ef970eba2daff))
* skip release-please's Maven SNAPSHOT bump PR ([ec50cfe](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/ec50cfef8e6c3ba8af9e73ade7ceadf3937b466b))
* un-comment CVE-ID lines in .trivyignore (whole file was commented out) ([214ac41](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/214ac412b2ca806f89d3715b9a56e5abc0ec7975))
* upgrade trivy-action to v0.36.0 (v0.32.0's default Trivy binary install failed silently) ([5c03cfd](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/5c03cfd221566f042612792ee5632d696ab58368))
* use GitHub username instead of personal email as .trivyignore owner ([4e7d94c](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/4e7d94c3fddb0cf937c2d0ee545bff694ad4905e))
* use https Maven settings namespace URI to pass nohttp-checkstyle ([50c3c07](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/50c3c0798705f63c69bfc332e8685b3b7337f4c2))


### Documentation

* add docs/ci-setup.md for one-time SonarCloud/GitHub Actions/GHCR setup ([15755d3](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/15755d3f274fd9097f29b9e7891449709e1af061))
* add SonarCloud Automatic Analysis vs CI-based Analysis conflict step ([37e9643](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/37e9643c030d454f0813aa144da93300fade84b1))
* add v2-cicd ADRs, architecture diagram, portability map, validation plan ([e0b26f0](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/e0b26f0a502772a08ee459c42cf3bdc2ba408ef7))
* add v2-cicd troubleshooting entries (quality gate, trivy, digest promotion, sonarqube host limits) ([0926665](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/0926665562c7cc39e80a5b6b6b3ad05c69686e0b))
* add Video Series, Challenges, and Command Reference to README ([0cd991a](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/0cd991a490024b8e98f856af8d0cc221146f81ff))
* add What This Teaches section to README ([6ff37f0](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/6ff37f06ca9727e84a8f2f8fbdcae4c4eade73b1))
* drop Challenges section, fold port-8080 note into Prerequisites ([3cb77ac](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/3cb77ac1aed5cf3c583aece1d2652535af434961))
* fix broken Milestones anchor and placeholder clone URL in README ([fd5d725](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/fd5d72523c09a33bc1c5f45491eb007d3ced9e01))
* flag ci/jenkins/Dockerfile HEALTHCHECK wget availability as unverified ([68f09ab](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/68f09abced333b2ee49f5207295032292b1d1408))
* fold V2 CI/CD into README (badges, milestones, architecture, run instructions) ([a1a1bae](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/a1a1bae655b7421741d4715283dc4db94797b012))
* record the v1.0.0 image-promotion incident in v2-cicd validation ([6563e25](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/6563e25489066c78ed50266bce3de3e662ad7c13))
* record V1 runtime verification results ([b74a465](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/b74a4652c7b756b793eafc4e513ec7ed237c2175))

## [1.0.2](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/compare/petclinic-v1.0.1...petclinic-v1.0.2) (2026-09-29)


### Bug Fixes

* race condition — release.yml ran concurrently with ci.yml, not after it ([3e51464](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/3e5146451718a4ab7ad90bd2fe3c295bf047ab5c))
* skip release-please's Maven SNAPSHOT bump PR ([ec50cfe](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/ec50cfef8e6c3ba8af9e73ade7ceadf3937b466b))

## [1.0.1](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/compare/petclinic-v1.0.0...petclinic-v1.0.1) (2026-09-29)


### Bug Fixes

* make digest-equality proof robust instead of fragile JSON grep ([9039216](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/90392167826c6fcea74fa6738ee2716e0815dfb1))


### Documentation

* record the v1.0.0 image-promotion incident in v2-cicd validation ([6563e25](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/6563e25489066c78ed50266bce3de3e662ad7c13))

## 1.0.0 (2026-09-29)


### Features

* add V1 containerized DevOps layer for PetClinic ([7fc3b7d](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/7fc3b7df6bef376db2b1eebddce429a61a2eb657))


### Bug Fixes

* accept 3 fixable-CRITICAL Tomcat CVEs via time-boxed .trivyignore ([ac1342b](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/ac1342ba27748f36cca713a45168d6d6c59bd4d2))
* add explicit deny-by-default top-level permissions to workflows ([a23aacf](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/a23aacfc9d9f6c294a5943339697e9df42c98ed8))
* add USER + HEALTHCHECK to ci/jenkins/Dockerfile for Checkov ([f413bd8](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/f413bd806ab35f375d1b64aa4fb42b30c97c77c8))
* lowercase GHCR image repository path ([8d7265d](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/8d7265d1f7cff3251bb9d659e5664a91394e4cf1))
* match sonar.projectKey to the real SonarCloud project key ([572cd87](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/572cd87e04f083d189c9fd516c894cad0c8bbad7))
* pin actions by real commit SHA, fix trivy-action tag, fix sonar config being silently ignored ([db43693](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/db43693f12d757902e4d1a66588e33522c081b62))
* pin actions by real commit SHA, fix trivy-action tag, fix sonar config being silently ignored ([b579291](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/b5792913cc58d5264bf661986bda16848772f2bb))
* quote actuator-blocking regex in nginx config ([5a1a706](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/5a1a706ff3f4f54523620931774b26cad5728663))
* release-please PR never triggers CI; sync README/docs with real CI results ([5fe08af](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/5fe08af88b4b8dd4465a741e9ec63453c56aa11e))
* restore executable bit on all shell scripts ([2da34f7](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/2da34f76294ca8a80a3ee8c99327f6f5f14aac8f))
* restore executable bit on gradlew and mvnw ([3f9cb30](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/3f9cb301819b0140dc7ef3abacc95c6fe9424ac6))
* restore V1 troubleshooting entries lost by a bad heredoc append ([04a7b35](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/04a7b35a170967a9520d36be653ef970eba2daff))
* un-comment CVE-ID lines in .trivyignore (whole file was commented out) ([214ac41](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/214ac412b2ca806f89d3715b9a56e5abc0ec7975))
* upgrade trivy-action to v0.36.0 (v0.32.0's default Trivy binary install failed silently) ([5c03cfd](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/5c03cfd221566f042612792ee5632d696ab58368))
* use GitHub username instead of personal email as .trivyignore owner ([4e7d94c](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/4e7d94c3fddb0cf937c2d0ee545bff694ad4905e))
* use https Maven settings namespace URI to pass nohttp-checkstyle ([50c3c07](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/50c3c0798705f63c69bfc332e8685b3b7337f4c2))


### Documentation

* add docs/ci-setup.md for one-time SonarCloud/GitHub Actions/GHCR setup ([15755d3](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/15755d3f274fd9097f29b9e7891449709e1af061))
* add SonarCloud Automatic Analysis vs CI-based Analysis conflict step ([37e9643](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/37e9643c030d454f0813aa144da93300fade84b1))
* add v2-cicd ADRs, architecture diagram, portability map, validation plan ([e0b26f0](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/e0b26f0a502772a08ee459c42cf3bdc2ba408ef7))
* add v2-cicd troubleshooting entries (quality gate, trivy, digest promotion, sonarqube host limits) ([0926665](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/0926665562c7cc39e80a5b6b6b3ad05c69686e0b))
* add Video Series, Challenges, and Command Reference to README ([0cd991a](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/0cd991a490024b8e98f856af8d0cc221146f81ff))
* add What This Teaches section to README ([6ff37f0](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/6ff37f06ca9727e84a8f2f8fbdcae4c4eade73b1))
* drop Challenges section, fold port-8080 note into Prerequisites ([3cb77ac](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/3cb77ac1aed5cf3c583aece1d2652535af434961))
* fix broken Milestones anchor and placeholder clone URL in README ([fd5d725](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/fd5d72523c09a33bc1c5f45491eb007d3ced9e01))
* flag ci/jenkins/Dockerfile HEALTHCHECK wget availability as unverified ([68f09ab](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/68f09abced333b2ee49f5207295032292b1d1408))
* fold V2 CI/CD into README (badges, milestones, architecture, run instructions) ([a1a1bae](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/a1a1bae655b7421741d4715283dc4db94797b012))
* record V1 runtime verification results ([b74a465](https://github.com/ThinkWithOps/thinkwithops-petclinic-production/commit/b74a4652c7b756b793eafc4e513ec7ed237c2175))
