#!/usr/bin/env python
try:
    from setuptools import setup
except ImportError:
    from distutils.core import setup

setup(
    name='ExasolMonitoringPlugins',
    version="2019.1",
    license="MIT",
    maintainer="Exasol AG",
    maintainer_email="support@exasol.com",
    description="Exasol monitoring plugins",
    long_description="Exasol monitoring plugins for Python >= 3.5",
    url='https://github.com/EXASOL/nagios-monitoring/wiki/Plugin-Descriptions',
    packages=[
        'ExasolMonitoringPlugins'
    ],
    install_requires=[
        'ExasolDatabaseConnector'
    ]
)

